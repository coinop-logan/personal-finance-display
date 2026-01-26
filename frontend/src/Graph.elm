module Graph exposing (viewGraph, viewMiniGraph)

import Api.Types exposing (BalanceSnapshot, WorkLog, Weather)
import Calculations exposing (dateToDays, calculateIncomingPay, calculateDailyPayForWorkLogs)
import Element exposing (Element, html, el, text, row, column, inFront, alignRight, alignTop, padding, paddingEach, spacing, rgb255, rgba)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Svg exposing (Svg, svg, rect, line, text_, g, polygon, polyline, circle)
import Svg.Attributes as SA
import Time


graphWidth : Float
graphWidth = 1920

graphHeight : Float
graphHeight = 1080

marginLeft : Float
marginLeft = 60

marginRight : Float
marginRight = 100

marginTop : Float
marginTop = 30

marginBottom : Float
marginBottom = 100

plotWidth : Float
plotWidth = graphWidth - marginLeft - marginRight

plotHeight : Float
plotHeight = graphHeight - marginTop - marginBottom

startDate : Int
startDate = dateToDays "2026-01-04"

yMax : Float
yMax = 20.0


colorGreen : String
colorGreen = "#4ade80"

colorEarnedLine : String
colorEarnedLine = "#1e40af"

colorYellow : String
colorYellow = "#fbbf24"

colorRed : String
colorRed = "#dc2626"

colorText : String
colorText = "#222"

colorAxis : String
colorAxis = "#000"

colorBackground : String
colorBackground = "#6b7aa0"

colorGridFaint : String
colorGridFaint = "rgba(0, 0, 0, 0.15)"

colorGridDay : String
colorGridDay = "rgba(0, 0, 0, 0.1)"

colorGridWeek : String
colorGridWeek = "rgba(0, 0, 0, 0.35)"

colorOrange : String
colorOrange = "#f97316"


type NoteColor
    = NoColor
    | NoteGreen
    | NoteBlue
    | NoteRed
    | NoteYellow

type alias NoteInfo =
    { color : NoteColor
    , text : String
    }

parseNote : String -> Maybe NoteInfo
parseNote encoded =
    if String.isEmpty encoded then
        Nothing
    else
        case String.split ":" encoded of
            colorStr :: rest ->
                let
                    noteText = String.join ":" rest
                    color = case colorStr of
                        "green" -> NoteGreen
                        "blue" -> NoteBlue
                        "red" -> NoteRed
                        "yellow" -> NoteYellow
                        _ -> NoColor
                in
                case color of
                    NoColor ->
                        if String.isEmpty encoded then Nothing else Just { color = NoColor, text = encoded }
                    _ ->
                        if String.isEmpty noteText then Nothing else Just { color = color, text = noteText }
            [] ->
                Nothing

type alias DayData =
    { day : Int
    , checking : Float
    , earnedMoney : Float
    , dailyPayEarned : Float
    , creditDrawn : Float
    , personalDebt : Float
    , creditLimit : Float
    , note : Maybe NoteInfo
    }


buildDayData : List BalanceSnapshot -> List WorkLog -> List DayData
buildDayData snapshots workLogs =
    let
        snapshotsByDay =
            snapshots
                |> List.map (\s -> ( dateToDays s.date, s ))
                |> List.sortBy Tuple.first

        buildForDay : Int -> BalanceSnapshot -> DayData
        buildForDay day snapshot =
            let
                incomingPay = calculateIncomingPay day workLogs
                dailyPay = calculateDailyPayForWorkLogs day workLogs
            in
            { day = day
            , checking = snapshot.checking / 1000
            , earnedMoney = (snapshot.checking + incomingPay) / 1000
            , dailyPayEarned = dailyPay / 1000
            , creditDrawn = (snapshot.creditLimit - snapshot.creditAvailable) / 1000
            , personalDebt = snapshot.personalDebt / 1000
            , creditLimit = snapshot.creditLimit / 1000
            , note = parseNote snapshot.note
            }
    in
    snapshotsByDay
        |> List.map (\( day, snapshot ) -> buildForDay day snapshot)


dayToX : Int -> Int -> Float
dayToX endDay day =
    let
        totalDays = endDay - startDate
        dayOffset = toFloat (day - startDate)
        totalDaysFloat = toFloat totalDays
    in
    marginLeft + (dayOffset / totalDaysFloat) * plotWidth

valueToY : Float -> Float -> Float
valueToY yMinK valueK =
    let
        range = yMax - yMinK
        normalized = (valueK - yMinK) / range
    in
    marginTop + plotHeight - (normalized * plotHeight)


formatK : Float -> String
formatK valueK =
    let
        rounded = toFloat (round (valueK * 100)) / 100
        intPart = floor (abs rounded)
        decPart = round ((abs rounded - toFloat intPart) * 100)
        decStr =
            if decPart == 0 then
                ""
            else if decPart < 10 then
                ".0" ++ String.fromInt decPart
            else
                "." ++ String.fromInt decPart
        sign = if rounded < 0 then "-" else ""
    in
    sign ++ "$" ++ String.fromInt intPart ++ decStr ++ "k"


dayLabelParts : Int -> { weekday : String, dayNum : String }
dayLabelParts day =
    let
        weekday = modBy 7 (day + 6)
        weekdayStr =
            case weekday of
                0 -> "Sun"
                1 -> "Mon"
                2 -> "Tue"
                3 -> "Wed"
                4 -> "Thu"
                5 -> "Fri"
                _ -> "Sat"

        dateStr = Calculations.daysToDateString day
        dayNum =
            String.split "-" dateStr
                |> List.drop 2
                |> List.head
                |> Maybe.andThen String.toInt
                |> Maybe.withDefault 0
    in
    { weekday = weekdayStr, dayNum = String.fromInt dayNum }


drawStepPolygon : Float -> Int -> Float -> List ( Int, Float ) -> String -> Svg msg
drawStepPolygon yMinK endDay baseline dayValues color =
    if List.isEmpty dayValues then
        g [] []
    else
        let
            y0 = valueToY yMinK baseline

            topEdge : Maybe ( Int, Float ) -> List ( Int, Float ) -> List String
            topEdge prevMaybe pts =
                case pts of
                    [] -> []
                    ( day, val ) :: rest ->
                        let
                            x1 = dayToX endDay day
                            x2 = dayToX endDay (day + 1)
                            y = valueToY yMinK val

                            gapPoints =
                                case prevMaybe of
                                    Just ( prevDay, prevVal ) ->
                                        if day > prevDay + 1 then
                                            let
                                                prevY = valueToY yMinK prevVal
                                            in
                                            [ String.fromFloat x1 ++ "," ++ String.fromFloat prevY ]
                                        else
                                            []
                                    Nothing ->
                                        []

                            thisPoints =
                                [ String.fromFloat x1 ++ "," ++ String.fromFloat y
                                , String.fromFloat x2 ++ "," ++ String.fromFloat y
                                ]
                        in
                        gapPoints ++ thisPoints ++ topEdge (Just ( day, val )) rest

            firstDay = List.head dayValues |> Maybe.map Tuple.first |> Maybe.withDefault startDate
            lastDay = List.reverse dayValues |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault startDate

            startX = dayToX endDay firstDay
            endX = dayToX endDay (lastDay + 1)

            pointsStr =
                [ String.fromFloat startX ++ "," ++ String.fromFloat y0 ]
                    ++ topEdge Nothing dayValues
                    ++ [ String.fromFloat endX ++ "," ++ String.fromFloat y0 ]
                    |> String.join " "
        in
        polygon
            [ SA.points pointsStr
            , SA.fill color
            , SA.fillOpacity "0.8"
            ]
            []


drawStepLine : Float -> Int -> List ( Int, Float ) -> String -> Svg msg
drawStepLine yMinK endDay dayValues color =
    if List.isEmpty dayValues then
        g [] []
    else
        let
            buildPoints : Maybe ( Int, Float ) -> List ( Int, Float ) -> List String
            buildPoints prevMaybe pts =
                case pts of
                    [] -> []
                    ( day, val ) :: rest ->
                        let
                            x1 = dayToX endDay day
                            x2 = dayToX endDay (day + 1)
                            y = valueToY yMinK val

                            gapPoints =
                                case prevMaybe of
                                    Just ( prevDay, prevVal ) ->
                                        if day > prevDay + 1 then
                                            let
                                                prevY = valueToY yMinK prevVal
                                            in
                                            [ String.fromFloat x1 ++ "," ++ String.fromFloat prevY ]
                                        else
                                            []
                                    Nothing ->
                                        []

                            thisPoints =
                                [ String.fromFloat x1 ++ "," ++ String.fromFloat y
                                , String.fromFloat x2 ++ "," ++ String.fromFloat y
                                ]
                        in
                        gapPoints ++ thisPoints ++ buildPoints (Just ( day, val )) rest

            pointsStr = buildPoints Nothing dayValues |> String.join " "
        in
        polyline
            [ SA.points pointsStr
            , SA.fill "none"
            , SA.stroke color
            , SA.strokeWidth "3"
            ]
            []


drawDailyPaySegments : Float -> Int -> List DayData -> Svg msg
drawDailyPaySegments yMinK endDay dayDataList =
    let
        buildSegments : Maybe DayData -> List DayData -> List (Svg msg)
        buildSegments prevMaybe remaining =
            case remaining of
                [] ->
                    []

                current :: rest ->
                    let
                        prevEarned =
                            case prevMaybe of
                                Just prev ->
                                    prev.earnedMoney

                                Nothing ->
                                    current.checking

                        segment =
                            if current.dailyPayEarned > 0 then
                                let
                                    x = dayToX endDay current.day
                                    yBottom = valueToY yMinK prevEarned
                                    yTop = valueToY yMinK (prevEarned + current.dailyPayEarned)
                                    rectWidth = 5
                                    rectHeight = yBottom - yTop
                                in
                                [ rect
                                    [ SA.x (String.fromFloat (x - rectWidth / 2))
                                    , SA.y (String.fromFloat yTop)
                                    , SA.width (String.fromFloat rectWidth)
                                    , SA.height (String.fromFloat rectHeight)
                                    , SA.fill colorOrange
                                    ]
                                    []
                                ]
                            else
                                []
                    in
                    segment ++ buildSegments (Just current) rest
    in
    g [] (buildSegments Nothing dayDataList)


drawNotes : Float -> Int -> List DayData -> Svg msg
drawNotes yMinK endDay dayDataList =
    let
        noteColors : NoteColor -> { dot : String, text : String }
        noteColors color =
            case color of
                NoteGreen -> { dot = "#22c55e", text = "#16a34a" }
                NoteBlue -> { dot = "#3b82f6", text = "#2563eb" }
                NoteRed -> { dot = "#ef4444", text = "#dc2626" }
                NoteYellow -> { dot = "#eab308", text = "#ca8a04" }
                NoColor -> { dot = "#9ca3af", text = "#6b7280" }

        drawNote : DayData -> List (Svg msg)
        drawNote dayData =
            case dayData.note of
                Nothing -> []
                Just noteInfo ->
                    let
                        colors = noteColors noteInfo.color

                        x = dayToX endDay dayData.day + (dayToX endDay (dayData.day + 1) - dayToX endDay dayData.day) / 2

                        dotY = valueToY yMinK (dayData.earnedMoney + 0.5)
                        dotRadius = 4

                        textX = x + 8
                        textY = dotY - 8
                    in
                    [ Svg.circle
                        [ SA.cx (String.fromFloat x)
                        , SA.cy (String.fromFloat dotY)
                        , SA.r (String.fromFloat dotRadius)
                        , SA.fill colors.dot
                        ]
                        []
                    , text_
                        [ SA.x (String.fromFloat textX)
                        , SA.y (String.fromFloat textY)
                        , SA.fill "#000000"
                        , SA.fontSize "14"
                        , SA.fontFamily "sans-serif"
                        , SA.fontWeight "bold"
                        , SA.transform ("rotate(-45 " ++ String.fromFloat textX ++ " " ++ String.fromFloat textY ++ ")")
                        ]
                        [ Svg.text noteInfo.text ]
                    ]
    in
    g [] (List.concatMap drawNote dayDataList)


drawXAxis : Float -> Int -> Svg msg
drawXAxis yMinK endDay =
    let
        y0 = valueToY yMinK 0

        axisLine =
            line
                [ SA.x1 (String.fromFloat marginLeft)
                , SA.y1 (String.fromFloat y0)
                , SA.x2 (String.fromFloat (graphWidth - marginRight))
                , SA.y2 (String.fromFloat y0)
                , SA.stroke colorAxis
                , SA.strokeWidth "2"
                ]
                []

        dayTicks =
            List.range startDate endDay
                |> List.map (\day ->
                    let
                        x = dayToX endDay day
                        labelParts = dayLabelParts day
                        centerX = x + (dayToX endDay (day + 1) - x) / 2
                    in
                    g []
                        [ line
                            [ SA.x1 (String.fromFloat x)
                            , SA.y1 (String.fromFloat y0)
                            , SA.x2 (String.fromFloat x)
                            , SA.y2 (String.fromFloat (y0 + 8))
                            , SA.stroke colorAxis
                            , SA.strokeWidth "2"
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat centerX)
                            , SA.y (String.fromFloat (y0 + 20))
                            , SA.fill colorText
                            , SA.fontSize "12"
                            , SA.textAnchor "middle"
                            ]
                            [ Svg.text labelParts.weekday ]
                        , text_
                            [ SA.x (String.fromFloat centerX)
                            , SA.y (String.fromFloat (y0 + 34))
                            , SA.fill colorText
                            , SA.fontSize "12"
                            , SA.textAnchor "middle"
                            ]
                            [ Svg.text labelParts.dayNum ]
                        ]
                )

        -- Week sections
        weekRowY = y0 + 42
        weekRowHeight = 16
        weeks = getWeekRanges startDate endDay
        weekSections =
            weeks
                |> List.indexedMap (\i ( weekStart, weekEnd ) ->
                    let
                        x1 = dayToX endDay (max weekStart startDate)
                        x2 = dayToX endDay (min (weekEnd + 1) (endDay + 1))
                        bgColor = if modBy 2 i == 0 then "rgba(0,0,0,0.1)" else "rgba(0,0,0,0.2)"
                        weekLabel = "week of " ++ formatShortDate weekStart
                    in
                    g []
                        [ rect
                            [ SA.x (String.fromFloat x1)
                            , SA.y (String.fromFloat weekRowY)
                            , SA.width (String.fromFloat (x2 - x1))
                            , SA.height (String.fromFloat weekRowHeight)
                            , SA.fill bgColor
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat ((x1 + x2) / 2))
                            , SA.y (String.fromFloat (weekRowY + 12))
                            , SA.fill colorText
                            , SA.fontSize "10"
                            , SA.textAnchor "middle"
                            ]
                            [ Svg.text weekLabel ]
                        ]
                )

        -- Month sections
        monthRowY = weekRowY + weekRowHeight
        monthRowHeight = 16
        months = getMonthRanges startDate endDay
        monthSections =
            months
                |> List.indexedMap (\i ( monthStart, monthEnd, monthName ) ->
                    let
                        x1 = dayToX endDay (max monthStart startDate)
                        x2 = dayToX endDay (min (monthEnd + 1) (endDay + 1))
                        bgColor = if modBy 2 i == 0 then "rgba(0,0,0,0.15)" else "rgba(0,0,0,0.25)"
                    in
                    g []
                        [ rect
                            [ SA.x (String.fromFloat x1)
                            , SA.y (String.fromFloat monthRowY)
                            , SA.width (String.fromFloat (x2 - x1))
                            , SA.height (String.fromFloat monthRowHeight)
                            , SA.fill bgColor
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat ((x1 + x2) / 2))
                            , SA.y (String.fromFloat (monthRowY + 12))
                            , SA.fill colorText
                            , SA.fontSize "11"
                            , SA.textAnchor "middle"
                            ]
                            [ Svg.text monthName ]
                        ]
                )

        -- Year sections
        yearRowY = monthRowY + monthRowHeight
        yearRowHeight = 16
        years = getYearRanges startDate endDay
        yearSections =
            years
                |> List.indexedMap (\i ( yearStart, yearEnd, yearNum ) ->
                    let
                        x1 = dayToX endDay (max yearStart startDate)
                        x2 = dayToX endDay (min (yearEnd + 1) (endDay + 1))
                        bgColor = if modBy 2 i == 0 then "rgba(0,0,0,0.2)" else "rgba(0,0,0,0.3)"
                    in
                    g []
                        [ rect
                            [ SA.x (String.fromFloat x1)
                            , SA.y (String.fromFloat yearRowY)
                            , SA.width (String.fromFloat (x2 - x1))
                            , SA.height (String.fromFloat yearRowHeight)
                            , SA.fill bgColor
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat ((x1 + x2) / 2))
                            , SA.y (String.fromFloat (yearRowY + 12))
                            , SA.fill colorText
                            , SA.fontSize "11"
                            , SA.textAnchor "middle"
                            , SA.fontWeight "bold"
                            ]
                            [ Svg.text (String.fromInt yearNum) ]
                        ]
                )
    in
    g [] (axisLine :: dayTicks ++ weekSections ++ monthSections ++ yearSections)


-- Helper to get Sunday of a week containing a given day
sundayOfWeek : Int -> Int
sundayOfWeek day =
    let
        -- day 0 (2000-01-01) was Saturday
        -- So: 0=Sat, 1=Sun, 2=Mon, ...
        dayOfWeek = modBy 7 day
    in
    if dayOfWeek == 0 then
        day - 6  -- Saturday: go back to previous Sunday
    else
        day - (dayOfWeek - 1)  -- Otherwise subtract to get to Sunday


-- Get list of (weekStart, weekEnd) tuples covering the date range
getWeekRanges : Int -> Int -> List ( Int, Int )
getWeekRanges rangeStart rangeEnd =
    let
        firstSunday = sundayOfWeek rangeStart

        buildWeeks sunday acc =
            if sunday > rangeEnd then
                List.reverse acc
            else
                let
                    weekEnd = sunday + 6
                in
                buildWeeks (sunday + 7) (( sunday, weekEnd ) :: acc)
    in
    buildWeeks firstSunday []


-- Format date as "M/D" (e.g., "1/5" for January 5)
formatShortDate : Int -> String
formatShortDate day =
    let
        dateStr = Calculations.daysToDateString day
        parts = String.split "-" dateStr
        month = parts |> List.drop 1 |> List.head |> Maybe.andThen String.toInt |> Maybe.withDefault 1
        dayNum = parts |> List.drop 2 |> List.head |> Maybe.andThen String.toInt |> Maybe.withDefault 1
    in
    String.fromInt month ++ "/" ++ String.fromInt dayNum


-- Get list of (monthStart, monthEnd, monthName) tuples covering the date range
getMonthRanges : Int -> Int -> List ( Int, Int, String )
getMonthRanges rangeStart rangeEnd =
    let
        -- Parse year/month from a day
        getYearMonth day =
            let
                dateStr = Calculations.daysToDateString day
                parts = String.split "-" dateStr
                year = parts |> List.head |> Maybe.andThen String.toInt |> Maybe.withDefault 2026
                month = parts |> List.drop 1 |> List.head |> Maybe.andThen String.toInt |> Maybe.withDefault 1
            in
            ( year, month )

        monthName m =
            case m of
                1 -> "January"
                2 -> "February"
                3 -> "March"
                4 -> "April"
                5 -> "May"
                6 -> "June"
                7 -> "July"
                8 -> "August"
                9 -> "September"
                10 -> "October"
                11 -> "November"
                12 -> "December"
                _ -> ""

        -- Get first day of a month
        firstDayOfMonth year month =
            dateToDays (String.fromInt year ++ "-" ++ String.padLeft 2 '0' (String.fromInt month) ++ "-01")

        -- Build month ranges
        buildMonths currentDay acc =
            if currentDay > rangeEnd then
                List.reverse acc
            else
                let
                    ( year, month ) = getYearMonth currentDay
                    monthStart = firstDayOfMonth year month
                    nextMonth = if month == 12 then 1 else month + 1
                    nextYear = if month == 12 then year + 1 else year
                    monthEnd = firstDayOfMonth nextYear nextMonth - 1
                in
                buildMonths (monthEnd + 1) (( monthStart, monthEnd, monthName month ) :: acc)
    in
    buildMonths rangeStart []


-- Get list of (yearStart, yearEnd, yearNum) tuples covering the date range
getYearRanges : Int -> Int -> List ( Int, Int, Int )
getYearRanges rangeStart rangeEnd =
    let
        getYear day =
            let
                dateStr = Calculations.daysToDateString day
                parts = String.split "-" dateStr
            in
            parts |> List.head |> Maybe.andThen String.toInt |> Maybe.withDefault 2026

        firstDayOfYear year =
            dateToDays (String.fromInt year ++ "-01-01")

        buildYears currentDay acc =
            if currentDay > rangeEnd then
                List.reverse acc
            else
                let
                    year = getYear currentDay
                    yearStart = firstDayOfYear year
                    yearEnd = firstDayOfYear (year + 1) - 1
                in
                buildYears (yearEnd + 1) (( yearStart, yearEnd, year ) :: acc)
    in
    buildYears rangeStart []


drawYAxis : Float -> Svg msg
drawYAxis yMinK =
    let
        tickValues =
            List.range (ceiling yMinK) (floor yMax)
                |> List.map toFloat

        ticks =
            tickValues
                |> List.map (\val ->
                    let
                        y = valueToY yMinK val
                    in
                    g []
                        [ line
                            [ SA.x1 (String.fromFloat (marginLeft - 8))
                            , SA.y1 (String.fromFloat y)
                            , SA.x2 (String.fromFloat marginLeft)
                            , SA.y2 (String.fromFloat y)
                            , SA.stroke colorAxis
                            , SA.strokeWidth "2"
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat (marginLeft - 12))
                            , SA.y (String.fromFloat (y + 5))
                            , SA.fill colorText
                            , SA.fontSize "16"
                            , SA.textAnchor "end"
                            ]
                            [ Svg.text (formatK val) ]
                        ]
                )

        axisLine =
            line
                [ SA.x1 (String.fromFloat marginLeft)
                , SA.y1 (String.fromFloat marginTop)
                , SA.x2 (String.fromFloat marginLeft)
                , SA.y2 (String.fromFloat (graphHeight - marginBottom))
                , SA.stroke colorAxis
                , SA.strokeWidth "2"
                ]
                []
    in
    g [] (axisLine :: ticks)


drawGridLines : Float -> Int -> Svg msg
drawGridLines yMinK endDay =
    let
        yGridValues =
            List.range (ceiling yMinK) (floor yMax)
                |> List.map toFloat

        horizontalLines =
            yGridValues
                |> List.map (\val ->
                    let
                        y = valueToY yMinK val
                    in
                    line
                        [ SA.x1 (String.fromFloat marginLeft)
                        , SA.y1 (String.fromFloat y)
                        , SA.x2 (String.fromFloat (graphWidth - marginRight))
                        , SA.y2 (String.fromFloat y)
                        , SA.stroke colorGridFaint
                        , SA.strokeWidth "1"
                        ]
                        []
                )

        dayLines =
            List.range startDate (endDay + 1)
                |> List.map (\day ->
                    let
                        x = dayToX endDay day
                        dayOfWeek = modBy 7 day
                        isSunday = dayOfWeek == 1
                        ( strokeColor, strokeW ) =
                            if isSunday then
                                ( colorGridWeek, "2" )
                            else
                                ( colorGridDay, "1" )
                    in
                    line
                        [ SA.x1 (String.fromFloat x)
                        , SA.y1 (String.fromFloat marginTop)
                        , SA.x2 (String.fromFloat x)
                        , SA.y2 (String.fromFloat (graphHeight - marginBottom))
                        , SA.stroke strokeColor
                        , SA.strokeWidth strokeW
                        ]
                        []
                )
    in
    g [] (horizontalLines ++ dayLines)


alaskaZone : Time.Zone
alaskaZone =
    Time.customZone (-9 * 60) []


-- Convert Time.Posix to days since 2000-01-01 (our epoch)
posixToDays : Time.Posix -> Int
posixToDays time =
    let
        year = Time.toYear alaskaZone time
        month = Time.toMonth alaskaZone time |> monthToInt
        day = Time.toDay alaskaZone time
        dateStr = String.fromInt year ++ "-" ++ String.padLeft 2 '0' (String.fromInt month) ++ "-" ++ String.padLeft 2 '0' (String.fromInt day)
    in
    dateToDays dateStr


monthToInt : Time.Month -> Int
monthToInt month =
    case month of
        Time.Jan -> 1
        Time.Feb -> 2
        Time.Mar -> 3
        Time.Apr -> 4
        Time.May -> 5
        Time.Jun -> 6
        Time.Jul -> 7
        Time.Aug -> 8
        Time.Sep -> 9
        Time.Oct -> 10
        Time.Nov -> 11
        Time.Dec -> 12


formatMilitaryTime : Time.Zone -> Time.Posix -> String
formatMilitaryTime zone time =
    let
        hour = Time.toHour zone time
        minute = Time.toMinute zone time
        second = Time.toSecond zone time
        pad n = if n < 10 then "0" ++ String.fromInt n else String.fromInt n
    in
    pad hour ++ ":" ++ pad minute ++ ":" ++ pad second


viewGraph : List BalanceSnapshot -> List WorkLog -> Time.Posix -> Maybe Weather -> Element msg
viewGraph snapshots workLogs currentTime maybeWeather =
    let
        -- Calculate today's day number from currentTime
        endDay = posixToDays currentTime

        dayData = buildDayData snapshots workLogs

        creditLimitK =
            snapshots
                |> List.reverse
                |> List.head
                |> Maybe.map (\s -> s.creditLimit / 1000)
                |> Maybe.withDefault 0.5

        yMinK = -creditLimitK

        checkingValues =
            dayData
                |> List.map (\d -> ( d.day, d.checking ))

        checkingPolygon = drawStepPolygon yMinK endDay 0 checkingValues colorGreen

        creditValues =
            dayData
                |> List.map (\d -> ( d.day, -d.creditDrawn ))

        creditPolygon = drawStepPolygon yMinK endDay 0 creditValues colorYellow

        dailyPaySegments = drawDailyPaySegments yMinK endDay dayData

        earnedValues =
            dayData
                |> List.map (\d -> ( d.day, d.earnedMoney ))

        earnedLine = drawStepLine yMinK endDay earnedValues colorEarnedLine

        debtValues =
            dayData
                |> List.map (\d -> ( d.day, d.personalDebt ))

        debtLine = drawStepLine yMinK endDay debtValues colorRed

        endLabels =
            case List.reverse dayData of
                latest :: _ ->
                    let
                        labelX = dayToX endDay (latest.day + 1) + 10
                        labelHeight = 20

                        rawLabels =
                            [ { desiredY = valueToY yMinK latest.checking
                              , color = colorGreen
                              , text = formatK latest.checking
                              }
                            ]
                            ++ (if latest.earnedMoney > 0 then
                                    [ { desiredY = valueToY yMinK latest.earnedMoney
                                      , color = colorEarnedLine
                                      , text = formatK latest.earnedMoney
                                      }
                                    ]
                                else
                                    []
                               )
                            ++ (if latest.creditDrawn > 0 then
                                    [ { desiredY = valueToY yMinK (-latest.creditDrawn)
                                      , color = colorYellow
                                      , text = formatK latest.creditDrawn
                                      }
                                    ]
                                else
                                    []
                               )
                            ++ (if latest.personalDebt > 0 then
                                    [ { desiredY = valueToY yMinK latest.personalDebt
                                      , color = colorRed
                                      , text = formatK latest.personalDebt
                                      }
                                    ]
                                else
                                    []
                               )

                        sortedLabels = List.sortBy .desiredY rawLabels

                        adjustedLabels =
                            List.foldl
                                (\label acc ->
                                    let
                                        prevBottom =
                                            case List.head (List.reverse acc) of
                                                Just prev -> prev.actualY + labelHeight
                                                Nothing -> 0
                                        actualY = max label.desiredY prevBottom
                                    in
                                    acc ++ [ { label | actualY = actualY } ]
                                )
                                []
                                (List.map (\l -> { desiredY = l.desiredY, color = l.color, text = l.text, actualY = l.desiredY }) sortedLabels)

                        renderLabel lbl =
                            text_
                                [ SA.x (String.fromFloat labelX)
                                , SA.y (String.fromFloat lbl.actualY)
                                , SA.fill lbl.color
                                , SA.fontSize "18"
                                , SA.dominantBaseline "middle"
                                ]
                                [ Svg.text lbl.text ]
                    in
                    g [ SA.textRendering "optimizeSpeed" ]
                        (List.map renderLabel adjustedLabels)
                _ ->
                    g [] []

        timeStr = formatMilitaryTime alaskaZone currentTime

        weatherStr =
            case maybeWeather of
                Just w ->
                    String.fromInt w.currentF ++ "° (" ++ String.fromInt w.lowF ++ "° - " ++ String.fromInt w.highF ++ "°)"

                Nothing ->
                    ""

        clockOverlay =
            el
                [ alignRight
                , alignTop
                , paddingEach { top = 10, right = round marginRight + 10, bottom = 0, left = 0 }
                ]
                (column
                    [ Background.color (rgba 0 0 0 0.35)
                    , Border.rounded 8
                    , padding 10
                    , spacing 4
                    , Font.family [ Font.monospace ]
                    , Font.color (rgb255 238 238 238)
                    ]
                    [ el [ Font.size 48 ] (text timeStr)
                    , if weatherStr /= "" then
                        el [ Font.size 28 ] (text weatherStr)
                      else
                        Element.none
                    ]
                )

        svgGraph =
            html <|
                svg
                    [ SA.width (String.fromFloat graphWidth)
                    , SA.height (String.fromFloat graphHeight)
                    , SA.viewBox ("0 0 " ++ String.fromFloat graphWidth ++ " " ++ String.fromFloat graphHeight)
                    , SA.shapeRendering "crispEdges"
                    ]
                    [ rect
                        [ SA.x "0"
                        , SA.y "0"
                        , SA.width (String.fromFloat graphWidth)
                        , SA.height (String.fromFloat graphHeight)
                        , SA.fill colorBackground
                        ]
                        []
                    , drawGridLines yMinK endDay
                    , checkingPolygon
                    , creditPolygon
                    , dailyPaySegments
                    , earnedLine
                    , debtLine
                    , drawYAxis yMinK
                    , drawXAxis yMinK endDay
                    , endLabels
                    , drawNotes yMinK endDay dayData
                    ]
    in
    el [ inFront clockOverlay ] svgGraph


viewMiniGraph : List BalanceSnapshot -> List WorkLog -> Element msg
viewMiniGraph snapshots workLogs =
    let
        miniWidth = 800
        miniHeight = 200
        miniMarginLeft = 50
        miniMarginRight = 60
        miniMarginTop = 15
        miniMarginBottom = 30
        miniPlotWidth = miniWidth - miniMarginLeft - miniMarginRight
        miniPlotHeight = miniHeight - miniMarginTop - miniMarginBottom

        dayData = buildDayData snapshots workLogs

        -- For mini graph, use fixed range based on data or reasonable default
        miniEndDay =
            dayData
                |> List.map .day
                |> List.maximum
                |> Maybe.withDefault startDate
                |> max (startDate + 7)  -- At least show a week

        miniTotalDays = miniEndDay - startDate

        creditLimitK =
            snapshots
                |> List.reverse
                |> List.head
                |> Maybe.map (\s -> s.creditLimit / 1000)
                |> Maybe.withDefault 0.5

        yMinK = -creditLimitK

        miniDayToX day =
            let
                dayOffset = toFloat (day - startDate)
                totalDaysFloat = toFloat miniTotalDays
            in
            miniMarginLeft + (dayOffset / totalDaysFloat) * miniPlotWidth

        miniValueToY valueK =
            let
                range = yMax - yMinK
                normalized = (valueK - yMinK) / range
            in
            miniMarginTop + miniPlotHeight - (normalized * miniPlotHeight)

        miniStepPolygon baseline dayValues color =
            if List.isEmpty dayValues then
                g [] []
            else
                let
                    yBase = miniValueToY baseline

                    topEdge prevMaybe pts =
                        case pts of
                            [] -> []
                            ( day, val ) :: rest ->
                                let
                                    x1 = miniDayToX day
                                    x2 = miniDayToX (day + 1)
                                    y = miniValueToY val
                                    gapPoints =
                                        case prevMaybe of
                                            Just ( prevDay, prevVal ) ->
                                                if day > prevDay + 1 then
                                                    [ String.fromFloat x1 ++ "," ++ String.fromFloat (miniValueToY prevVal) ]
                                                else
                                                    []
                                            Nothing -> []
                                    thisPoints =
                                        [ String.fromFloat x1 ++ "," ++ String.fromFloat y
                                        , String.fromFloat x2 ++ "," ++ String.fromFloat y
                                        ]
                                in
                                gapPoints ++ thisPoints ++ topEdge (Just ( day, val )) rest

                    firstDay = List.head dayValues |> Maybe.map Tuple.first |> Maybe.withDefault startDate
                    lastDay = List.reverse dayValues |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault startDate
                    startX = miniDayToX firstDay
                    endX = miniDayToX (lastDay + 1)

                    pointsStr =
                        [ String.fromFloat startX ++ "," ++ String.fromFloat yBase ]
                            ++ topEdge Nothing dayValues
                            ++ [ String.fromFloat endX ++ "," ++ String.fromFloat yBase ]
                            |> String.join " "
                in
                polygon
                    [ SA.points pointsStr
                    , SA.fill color
                    , SA.fillOpacity "0.8"
                    ]
                    []

        miniStepLine dayValues color =
            if List.isEmpty dayValues then
                g [] []
            else
                let
                    buildPoints prevMaybe pts =
                        case pts of
                            [] -> []
                            ( day, val ) :: rest ->
                                let
                                    x1 = miniDayToX day
                                    x2 = miniDayToX (day + 1)
                                    y = miniValueToY val
                                    gapPoints =
                                        case prevMaybe of
                                            Just ( prevDay, prevVal ) ->
                                                if day > prevDay + 1 then
                                                    [ String.fromFloat x1 ++ "," ++ String.fromFloat (miniValueToY prevVal) ]
                                                else
                                                    []
                                            Nothing -> []
                                    thisPoints =
                                        [ String.fromFloat x1 ++ "," ++ String.fromFloat y
                                        , String.fromFloat x2 ++ "," ++ String.fromFloat y
                                        ]
                                in
                                gapPoints ++ thisPoints ++ buildPoints (Just ( day, val )) rest

                    pointsStr = buildPoints Nothing dayValues |> String.join " "
                in
                polyline
                    [ SA.points pointsStr
                    , SA.fill "none"
                    , SA.stroke color
                    , SA.strokeWidth "2"
                    ]
                    []

        checkingValues = List.map (\d -> ( d.day, d.checking )) dayData
        creditValues = List.map (\d -> ( d.day, -d.creditDrawn )) dayData
        earnedValues = List.map (\d -> ( d.day, d.earnedMoney )) dayData
        debtValues = List.map (\d -> ( d.day, d.personalDebt )) dayData

        y0 = miniValueToY 0
        zeroLine =
            line
                [ SA.x1 (String.fromFloat miniMarginLeft)
                , SA.y1 (String.fromFloat y0)
                , SA.x2 (String.fromFloat (miniWidth - miniMarginRight))
                , SA.y2 (String.fromFloat y0)
                , SA.stroke colorAxis
                , SA.strokeWidth "1"
                ]
                []
    in
    html <|
        svg
            [ SA.width (String.fromFloat miniWidth)
            , SA.height (String.fromFloat miniHeight)
            , SA.viewBox ("0 0 " ++ String.fromFloat miniWidth ++ " " ++ String.fromFloat miniHeight)
            , SA.shapeRendering "crispEdges"
            ]
            [ rect
                [ SA.x "0"
                , SA.y "0"
                , SA.width (String.fromFloat miniWidth)
                , SA.height (String.fromFloat miniHeight)
                , SA.fill colorBackground
                , SA.rx "8"
                ]
                []
            , miniStepPolygon 0 checkingValues colorGreen
            , miniStepPolygon 0 creditValues colorYellow
            , miniStepLine earnedValues colorEarnedLine
            , miniStepLine debtValues colorRed
            , zeroLine
            ]
