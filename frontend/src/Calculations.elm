module Calculations exposing
    ( incomingPayForEntry
    , dateToWeekNumber
    , dateToDays
    , daysToDateString
    , dayOfWeekName
    )

{-| Financial calculations module.

These calculations are designed to be reusable across the entry page display
and the graph visualization.
-}

import Api.Types exposing (Entry)


-- DATE HELPERS (needed for week calculations)


{-| Convert date string "YYYY-MM-DD" to days since epoch (2000-01-01 = 0)
-}
dateToDays : String -> Int
dateToDays dateStr =
    case parseDate dateStr of
        Just ( year, month, day ) ->
            daysSinceEpoch year month day

        Nothing ->
            0


{-| Convert days since epoch back to "YYYY-MM-DD" string
-}
daysToDateString : Int -> String
daysToDateString days =
    let
        ( year, month, day ) = dateFromDays days
    in
    formatDate year month day


{-| Get three-letter weekday name from days since epoch.
2000-01-01 was a Saturday.
-}
dayOfWeekName : Int -> String
dayOfWeekName days =
    -- 2000-01-01 (day 0) was Saturday
    -- So: 0=Sat, 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri
    case modBy 7 days of
        0 -> "Sat"
        1 -> "Sun"
        2 -> "Mon"
        3 -> "Tue"
        4 -> "Wed"
        5 -> "Thu"
        6 -> "Fri"
        _ -> "???"  -- Should never happen


parseDate : String -> Maybe ( Int, Int, Int )
parseDate str =
    case String.split "-" str of
        [ yearStr, monthStr, dayStr ] ->
            Maybe.map3 (\y m d -> ( y, m, d ))
                (String.toInt yearStr)
                (String.toInt monthStr)
                (String.toInt dayStr)

        _ ->
            Nothing


formatDate : Int -> Int -> Int -> String
formatDate year month day =
    String.fromInt year
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt month)
        ++ "-"
        ++ String.padLeft 2 '0' (String.fromInt day)


daysSinceEpoch : Int -> Int -> Int -> Int
daysSinceEpoch year month day =
    let
        y = year - 2000
        leapYears = (y + 3) // 4
        daysInPriorYears = y * 365 + leapYears
        daysInPriorMonths = daysBeforeMonth year month
    in
    daysInPriorYears + daysInPriorMonths + day - 1


dateFromDays : Int -> ( Int, Int, Int )
dateFromDays totalDays =
    let
        approxYear = 2000 + (totalDays * 400) // 146097
        year = findYear approxYear totalDays
        dayOfYear = totalDays - daysSinceEpoch year 1 1
        ( month, day ) = monthAndDayFromDayOfYear year (dayOfYear + 1)
    in
    ( year, month, day )


findYear : Int -> Int -> Int
findYear year totalDays =
    if daysSinceEpoch (year + 1) 1 1 <= totalDays then
        findYear (year + 1) totalDays
    else if daysSinceEpoch year 1 1 > totalDays then
        findYear (year - 1) totalDays
    else
        year


monthAndDayFromDayOfYear : Int -> Int -> ( Int, Int )
monthAndDayFromDayOfYear year dayOfYear =
    findMonth year 1 dayOfYear


findMonth : Int -> Int -> Int -> ( Int, Int )
findMonth year month remainingDays =
    let
        daysInThisMonth = daysInMonth year month
    in
    if remainingDays <= daysInThisMonth then
        ( month, remainingDays )
    else
        findMonth year (month + 1) (remainingDays - daysInThisMonth)


daysBeforeMonth : Int -> Int -> Int
daysBeforeMonth year month =
    List.range 1 (month - 1)
        |> List.map (daysInMonth year)
        |> List.sum


daysInMonth : Int -> Int -> Int
daysInMonth year month =
    case month of
        1 -> 31
        2 -> if isLeapYear year then 29 else 28
        3 -> 31
        4 -> 30
        5 -> 31
        6 -> 30
        7 -> 31
        8 -> 31
        9 -> 30
        10 -> 31
        11 -> 30
        12 -> 31
        _ -> 30


isLeapYear : Int -> Bool
isLeapYear year =
    (modBy 4 year == 0) && (modBy 100 year /= 0 || modBy 400 year == 0)


-- WEEK CALCULATIONS


{-| Get week number from days since epoch.
Week starts on Sunday (consistent with typical US payroll).
-}
dateToWeekNumber : Int -> Int
dateToWeekNumber days =
    -- 2000-01-01 was a Saturday, so day 0 is in week 0
    -- Sunday would be day 1, which starts week 1
    (days + 1) // 7


{-| Get the Sunday (first day) of the week containing the given day -}
sundayOfWeek : Int -> Int
sundayOfWeek days =
    -- 2000-01-01 (day 0) was Saturday
    -- So: 0=Sat, 1=Sun, 2=Mon, ...
    -- To get Sunday: subtract (dayOfWeek - 1), but handle Saturday specially
    let
        dayOfWeek = modBy 7 days  -- 0=Sat, 1=Sun, 2=Mon, etc.
    in
    if dayOfWeek == 0 then
        -- Saturday: Sunday is tomorrow, but we want *previous* Sunday
        days - 6
    else
        -- Sunday=1, Mon=2, etc. Subtract (dayOfWeek - 1) to get to Sunday
        days - (dayOfWeek - 1)


-- INCOMING PAY CALCULATIONS


{-| Calculate incoming pay as of a specific entry's date.

Algorithm:
1. Find Sunday of the row's week (start of current pay period)
2. Check if any day from that Sunday up to the row's date has payCashed=true
   - If yes: only count current week's hours
   - If no: count current week + previous week's hours
3. For each week, iterate through days chronologically, tracking:
   - Regular hours (capped at 8/day, 40/week)
   - Overtime hours (daily >8 OR weekly >40, at 1.5x)
4. Apply tax multiplier (placeholder, currently 1.0)
-}
incomingPayForEntry : Entry -> List Entry -> Float
incomingPayForEntry targetEntry allEntries =
    let
        -- Tax multiplier placeholder: 1.0 means no tax deducted
        taxMultiplier = 1.0

        targetDays = dateToDays targetEntry.date
        currentWeekSunday = sundayOfWeek targetDays
        previousWeekSunday = currentWeekSunday - 7

        -- Get entries up to and including the target date, sorted by date
        entriesUpToTarget =
            allEntries
                |> List.filter (\e -> dateToDays e.date <= targetDays)
                |> List.sortBy .date

        -- Check if any day in current week (from Sunday to target date) has payCashed=true
        currentWeekHasCashed =
            entriesUpToTarget
                |> List.any (\e ->
                    let
                        eDays = dateToDays e.date
                    in
                    eDays >= currentWeekSunday && eDays <= targetDays && e.payCashed
                )

        -- Determine which weeks to count
        -- If current week has a cashed entry, only count current week
        -- Otherwise, count current week + previous week
        startDay =
            if currentWeekHasCashed then
                currentWeekSunday
            else
                previousWeekSunday

        -- Get entries in the range we're counting
        relevantEntries =
            entriesUpToTarget
                |> List.filter (\e -> dateToDays e.date >= startDay)

        -- Get pay rate from target entry (or most recent entry with a rate)
        payPerHour = targetEntry.payPerHour

        -- Calculate pay for current week
        currentWeekEntries =
            relevantEntries
                |> List.filter (\e -> dateToDays e.date >= currentWeekSunday)
                |> List.sortBy .date

        currentWeekPay = calculateWeekPayWithOvertime currentWeekEntries payPerHour

        -- Calculate pay for previous week (if we're counting it)
        previousWeekPay =
            if currentWeekHasCashed then
                0
            else
                let
                    prevWeekEntries =
                        relevantEntries
                            |> List.filter (\e ->
                                let eDays = dateToDays e.date
                                in eDays >= previousWeekSunday && eDays < currentWeekSunday
                            )
                            |> List.sortBy .date
                in
                calculateWeekPayWithOvertime prevWeekEntries payPerHour
    in
    (currentWeekPay + previousWeekPay) * taxMultiplier


{-| Calculate pay for a week with Alaska overtime rules.

Iterates through days chronologically, tracking:
- Daily overtime: any hours over 8 in a single day
- Weekly overtime: once regular hours hit 40, additional regular hours become overtime

Note: Overtime hours do NOT count toward the 40-hour weekly threshold.
-}
calculateWeekPayWithOvertime : List Entry -> Float -> Float
calculateWeekPayWithOvertime entries payPerHour =
    let
        -- Process each day, accumulating regular and overtime hours
        processDay : Entry -> { regular : Float, overtime : Float } -> { regular : Float, overtime : Float }
        processDay entry acc =
            let
                hoursToday = entry.hoursWorked

                -- Daily overtime: hours over 8
                dailyRegular = min hoursToday 8
                dailyOvertime = max 0 (hoursToday - 8)

                -- Check if adding dailyRegular would exceed 40 weekly regular hours
                regularRoomLeft = max 0 (40 - acc.regular)
                regularToAdd = min dailyRegular regularRoomLeft
                weeklyOverflowToOvertime = dailyRegular - regularToAdd

                -- Total overtime for this day = daily overtime + any weekly overflow
                totalOvertimeToday = dailyOvertime + weeklyOverflowToOvertime
            in
            { regular = acc.regular + regularToAdd
            , overtime = acc.overtime + totalOvertimeToday
            }

        result =
            List.foldl processDay { regular = 0, overtime = 0 } entries
    in
    (result.regular * payPerHour) + (result.overtime * payPerHour * 1.5)
