module Calculations exposing
    ( calculateIncomingPay
    , calculateDailyPayForWorkLogs
    , dateToDays
    , daysToDateString
    , dayOfWeekName
    )

import Api.Types exposing (WorkLog, BalanceSnapshot)
import Dict exposing (Dict)


dateToDays : String -> Int
dateToDays dateStr =
    case parseDate dateStr of
        Just ( year, month, day ) ->
            daysSinceEpoch year month day

        Nothing ->
            0


daysToDateString : Int -> String
daysToDateString days =
    let
        ( year, month, day ) = dateFromDays days
    in
    formatDate year month day


dayOfWeekName : Int -> String
dayOfWeekName days =
    case modBy 7 days of
        0 -> "Sat"
        1 -> "Sun"
        2 -> "Mon"
        3 -> "Tue"
        4 -> "Wed"
        5 -> "Thu"
        6 -> "Fri"
        _ -> "???"


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


sundayOfWeek : Int -> Int
sundayOfWeek days =
    let
        dayOfWeek = modBy 7 days
    in
    if dayOfWeek == 0 then
        days - 6
    else
        days - (dayOfWeek - 1)


calculateIncomingPay : Int -> List WorkLog -> Float
calculateIncomingPay targetDay workLogs =
    let
        currentWeekSunday = sundayOfWeek targetDay
        previousWeekSunday = currentWeekSunday - 7

        logsUpToTarget =
            workLogs
                |> List.filter (\w -> dateToDays w.date <= targetDay)

        currentWeekLogs =
            logsUpToTarget
                |> List.filter (\w -> dateToDays w.date >= currentWeekSunday)

        -- Check if any log in current week (up to target date) has payCashed=true
        hasPayCashedInCurrentWeek =
            currentWeekLogs
                |> List.any .payCashed

        previousWeekLogs =
            logsUpToTarget
                |> List.filter (\w ->
                    let wDays = dateToDays w.date
                    in wDays >= previousWeekSunday && wDays < currentWeekSunday
                )

        currentWeekPay = calculateWeekPayByJob currentWeekLogs

        -- Only count previous week if no payCashed in current week
        previousWeekPay =
            if hasPayCashedInCurrentWeek then
                0
            else
                calculateWeekPayByJob previousWeekLogs
    in
    currentWeekPay + previousWeekPay


calculateWeekPayByJob : List WorkLog -> Float
calculateWeekPayByJob logs =
    let
        logsByJob : Dict String (List WorkLog)
        logsByJob =
            logs
                |> List.foldl
                    (\log acc ->
                        let
                            existing = Dict.get log.jobId acc |> Maybe.withDefault []
                        in
                        Dict.insert log.jobId (log :: existing) acc
                    )
                    Dict.empty

        payPerJob : List Float
        payPerJob =
            Dict.values logsByJob
                |> List.map (\jobLogs ->
                    jobLogs
                        |> List.sortBy .date
                        |> calculateWeekPayWithOvertime
                )
    in
    List.sum payPerJob


calculateWeekPayWithOvertime : List WorkLog -> Float
calculateWeekPayWithOvertime logs =
    let
        processDay : WorkLog -> { accumulatedRegular : Float, totalPay : Float } -> { accumulatedRegular : Float, totalPay : Float }
        processDay log acc =
            let
                dayPay = calculateDailyPayForLog log acc.accumulatedRegular
                dailyRegular = min log.hours 8
                regularRoomLeft = max 0 (40 - acc.accumulatedRegular)
                regularAdded = min dailyRegular regularRoomLeft
            in
            { accumulatedRegular = acc.accumulatedRegular + regularAdded
            , totalPay = acc.totalPay + dayPay
            }

        result =
            List.foldl processDay { accumulatedRegular = 0, totalPay = 0 } logs
    in
    result.totalPay


calculateDailyPayForLog : WorkLog -> Float -> Float
calculateDailyPayForLog log accumulatedWeeklyRegular =
    let
        taxMultiplier = 1.0 - log.taxRate

        dailyRegular = min log.hours 8
        dailyOvertime = max 0 (log.hours - 8)

        regularRoomLeft = max 0 (40 - accumulatedWeeklyRegular)
        regularHours = min dailyRegular regularRoomLeft
        weeklyOvertime = dailyRegular - regularHours
        totalOvertime = dailyOvertime + weeklyOvertime

        regularPay = regularHours * log.payRate
        overtimePay = totalOvertime * log.payRate * 1.5
    in
    (regularPay + overtimePay) * taxMultiplier


calculateDailyPayForWorkLogs : Int -> List WorkLog -> Float
calculateDailyPayForWorkLogs targetDay allWorkLogs =
    let
        weekSunday = sundayOfWeek targetDay

        logsInWeekBeforeTarget =
            allWorkLogs
                |> List.filter (\w ->
                    let wDay = dateToDays w.date
                    in wDay >= weekSunday && wDay < targetDay
                )

        logsOnTargetDay =
            allWorkLogs
                |> List.filter (\w -> dateToDays w.date == targetDay)

        logsByJob : Dict String (List WorkLog)
        logsByJob =
            logsInWeekBeforeTarget
                |> List.foldl
                    (\log acc ->
                        let existing = Dict.get log.jobId acc |> Maybe.withDefault []
                        in Dict.insert log.jobId (log :: existing) acc
                    )
                    Dict.empty

        accumulatedHoursByJob : Dict String Float
        accumulatedHoursByJob =
            Dict.map
                (\_ logs ->
                    logs
                        |> List.map (\l -> min l.hours 8)
                        |> List.sum
                )
                logsByJob

        payForTargetDay =
            logsOnTargetDay
                |> List.map (\log ->
                    let
                        accHours = Dict.get log.jobId accumulatedHoursByJob |> Maybe.withDefault 0
                    in
                    calculateDailyPayForLog log accHours
                )
                |> List.sum
    in
    payForTargetDay
