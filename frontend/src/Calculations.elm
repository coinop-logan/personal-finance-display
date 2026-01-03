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


-- INCOMING PAY CALCULATIONS


{-| Calculate incoming pay as of a specific entry's date.

For entry E in week N:
- Look at all entries from week N and earlier
- Exclude any week W where a week > W has payCashed = true
- Apply overtime rules to remaining weeks
- Sum up the pay

This gives "how much pay is owed as of this entry's date"
-}
incomingPayForEntry : Entry -> List Entry -> Float
incomingPayForEntry targetEntry allEntries =
    let
        -- Tax multiplier placeholder: 1.0 means no tax deducted
        taxMultiplier = 1.0

        targetWeek = dateToWeekNumber (dateToDays targetEntry.date)

        -- Get all entries up to and including the target entry's week
        entriesUpToTarget =
            allEntries
                |> List.filter (\e -> dateToWeekNumber (dateToDays e.date) <= targetWeek)

        -- Find the most recent week (up to targetWeek) that has been "cashed out"
        -- A week W is cashed if any entry in week > W has payCashed = true
        -- So we look for payCashed entries in weeks > each candidate week
        mostRecentCashedWeek =
            entriesUpToTarget
                |> List.filter .payCashed
                |> List.map (\e -> dateToWeekNumber (dateToDays e.date) - 1)  -- payCashed in week N means week N-1 is cashed
                |> List.maximum
                |> Maybe.withDefault -1

        -- Filter to entries in weeks AFTER the most recently cashed week
        uncashedEntries =
            entriesUpToTarget
                |> List.filter (\e -> dateToWeekNumber (dateToDays e.date) > mostRecentCashedWeek)

        -- Group entries by week for overtime calculation
        weeklyGroups = groupByWeek uncashedEntries

        -- Calculate pay for each week with overtime
        weeklyPay = List.map calculateWeekPay weeklyGroups
    in
    List.sum weeklyPay * taxMultiplier


{-| Group entries by week number -}
groupByWeek : List Entry -> List (List Entry)
groupByWeek entries =
    let
        weekNumbers =
            entries
                |> List.map (\e -> dateToWeekNumber (dateToDays e.date))
                |> uniqueInts
    in
    weekNumbers
        |> List.map (\wn ->
            List.filter (\e -> dateToWeekNumber (dateToDays e.date) == wn) entries
        )


uniqueInts : List Int -> List Int
uniqueInts list =
    List.foldr
        (\x acc ->
            if List.member x acc then
                acc
            else
                x :: acc
        )
        []
        list


{-| Calculate pay for a single week with Alaska overtime rules.
Overtime: >8 hours/day OR >40 hours/week = 1.5x
-}
calculateWeekPay : List Entry -> Float
calculateWeekPay weekEntries =
    let
        -- First, calculate daily overtime for each day
        dailyResults =
            weekEntries
                |> List.map (\entry ->
                    let
                        regularHours = min entry.hoursWorked 8
                        dailyOvertimeHours = max 0 (entry.hoursWorked - 8)
                    in
                    { entry = entry
                    , regularHours = regularHours
                    , dailyOvertimeHours = dailyOvertimeHours
                    }
                )

        -- Sum up regular hours (after daily overtime removed)
        totalRegularHours = List.sum (List.map .regularHours dailyResults)

        -- Sum up daily overtime hours
        totalDailyOvertimeHours = List.sum (List.map .dailyOvertimeHours dailyResults)

        -- Check for weekly overtime (>40 regular hours)
        weeklyRegularHours = min totalRegularHours 40
        weeklyOvertimeHours = max 0 (totalRegularHours - 40)

        -- Total overtime = daily overtime + weekly overtime
        totalOvertimeHours = totalDailyOvertimeHours + weeklyOvertimeHours

        -- Final regular hours
        finalRegularHours = weeklyRegularHours

        -- Get pay rate (use first entry's rate, or 0 if empty)
        payPerHour =
            weekEntries
                |> List.head
                |> Maybe.map .payPerHour
                |> Maybe.withDefault 0
    in
    (finalRegularHours * payPerHour) + (totalOvertimeHours * payPerHour * 1.5)
