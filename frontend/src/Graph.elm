module Graph exposing (viewGraph, viewMiniGraph)

import Api.Types exposing (Entry, Weather)
import Calculations exposing (dateToDays, incomingPayForEntry, calculateDailyPay)
import Element exposing (Element, html, el, text, row, column, inFront, alignRight, alignTop, padding, paddingEach, spacing, rgb255, rgba)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Svg exposing (Svg, svg, rect, line, text_, g, polygon, polyline, circle)
import Svg.Attributes as SA
import Time


-- CONSTANTS (1920x1080 full HD)
-- DO NOT CHANGE these dimensions - they match the Pi's display resolution

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
marginBottom = 50

plotWidth : Float
plotWidth = graphWidth - marginLeft - marginRight

plotHeight : Float
plotHeight = graphHeight - marginTop - marginBottom

-- Date range: 2025-12-29 to 2026-01-31
startDate : Int
startDate = dateToDays "2025-12-29"

endDate : Int
endDate = dateToDays "2026-01-31"

totalDays : Int
totalDays = endDate - startDate

-- Y axis: yMin will be calculated from credit limit, yMax is 20k
yMax : Float
yMax = 20.0  -- in thousands


-- COLORS

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


-- GRAPH DATA

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
                        -- No valid color prefix, treat whole string as note with no color
                        if String.isEmpty encoded then Nothing else Just { color = NoColor, text = encoded }
                    _ ->
                        if String.isEmpty noteText then Nothing else Just { color = color, text = noteText }
            [] ->
                Nothing

type alias DayData =
    { day : Int
    , checking : Float  -- in k
    , earnedMoney : Float  -- checking + incoming pay, in k
    , dailyPayEarned : Float  -- pay earned just today (with OT), in k
    , creditDrawn : Float  -- credit limit - credit available, in k
    , personalDebt : Float  -- in k
    , creditLimit : Float  -- in k
    , note : Maybe NoteInfo
    }


buildDayData : List Entry -> List DayData
buildDayData entries =
    let
        entriesByDay =
            entries
                |> List.map (\e -> ( dateToDays e.date, e ))
                |> List.sortBy Tuple.first

        -- Get Sunday of the week containing this day
        -- 2000-01-01 (day 0) was Saturday, so day 1 was Sunday
        -- dayOfWeek: 0=Sat, 1=Sun, 2=Mon, etc.
        sundayOfWeek : Int -> Int
        sundayOfWeek day =
            let
                dayOfWeek = modBy 7 day
            in
            if dayOfWeek == 0 then
                -- Saturday: previous Sunday is 6 days back
                day - 6
            else
                -- Sunday=1, Mon=2, etc. Go back (dayOfWeek - 1) days
                day - (dayOfWeek - 1)

        -- Calculate accumulated regular hours earlier in the current week
        -- (not including the target day)
        accumulatedHoursInWeek : Int -> Float
        accumulatedHoursInWeek targetDay =
            let
                weekSunday = sundayOfWeek targetDay
            in
            entriesByDay
                |> List.filter (\( day, _ ) -> day >= weekSunday && day < targetDay)
                |> List.foldl
                    (\( _, entry ) acc ->
                        -- Only count up to 8 regular hours per day toward the 40hr threshold
                        acc + min entry.hoursWorked 8
                    )
                    0

        buildForDay : Int -> Entry -> DayData
        buildForDay day entry =
            let
                incomingPay = incomingPayForEntry entry entries
                accumulatedHours = accumulatedHoursInWeek day
                dailyPay = calculateDailyPay entry.hoursWorked entry.payPerHour accumulatedHours
            in
            { day = day
            , checking = entry.checking / 1000
            , earnedMoney = (entry.checking + incomingPay) / 1000
            , dailyPayEarned = dailyPay / 1000
            , creditDrawn = (entry.creditLimit - entry.creditAvailable) / 1000
            , personalDebt = entry.personalDebt / 1000
            , creditLimit = entry.creditLimit / 1000
            , note = parseNote entry.note
            }
    in
    entriesByDay
        |> List.map (\( day, entry ) -> buildForDay day entry)


-- COORDINATE TRANSFORMS

dayToX : Float -> Int -> Float
dayToX yMinK day =
    let
        dayOffset = toFloat (day - startDate)
        totalDaysFloat = toFloat totalDays
    in
    marginLeft + (dayOffset / totalDaysFloat) * plotWidth

valueToY : Float -> Float -> Float
valueToY yMinK valueK =
    -- Y axis is inverted in SVG (0 at top)
    let
        range = yMax - yMinK
        normalized = (valueK - yMinK) / range
    in
    marginTop + plotHeight - (normalized * plotHeight)


-- FORMAT HELPERS

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


dayLabel : Int -> String
dayLabel day =
    let
        -- Calculate weekday (0=Sunday, 1=Monday, etc.)
        -- 2000-01-01 was a Saturday (6)
        weekday = modBy 7 (day + 6)
        weekdayLetter =
            case weekday of
                0 -> "S"
                1 -> "M"
                2 -> "T"
                3 -> "W"
                4 -> "T"
                5 -> "F"
                _ -> "S"

        -- Get day of month from date string
        dateStr = Calculations.daysToDateString day
        dayNum =
            String.split "-" dateStr
                |> List.drop 2
                |> List.head
                |> Maybe.andThen String.toInt
                |> Maybe.withDefault 0
    in
    weekdayLetter ++ String.fromInt dayNum


-- DRAWING PRIMITIVES

{-| Draw a filled step polygon from baseline to values.
    For bars: creates outline of all bars as one shape.
    Goes: start at baseline, step up to first value, across to next day,
    step to next value, etc., then back down to baseline.

    Handles gaps: if there's a gap between days, extends the previous value
    horizontally until the next data point.
-}
drawStepPolygon : Float -> Float -> List ( Int, Float ) -> String -> Svg msg
drawStepPolygon yMinK baseline dayValues color =
    if List.isEmpty dayValues then
        g [] []
    else
        let
            y0 = valueToY yMinK baseline

            -- Build the top edge of the polygon, handling gaps between days
            topEdge : Maybe ( Int, Float ) -> List ( Int, Float ) -> List String
            topEdge prevMaybe pts =
                case pts of
                    [] -> []
                    ( day, val ) :: rest ->
                        let
                            x1 = dayToX yMinK day
                            x2 = dayToX yMinK (day + 1)
                            y = valueToY yMinK val

                            -- If there's a gap from previous day, extend previous value to this day's start
                            gapPoints =
                                case prevMaybe of
                                    Just ( prevDay, prevVal ) ->
                                        if day > prevDay + 1 then
                                            -- There's a gap: extend previous value to start of this day
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

            -- Get the x coordinates for baseline
            firstDay = List.head dayValues |> Maybe.map Tuple.first |> Maybe.withDefault startDate
            lastDay = List.reverse dayValues |> List.head |> Maybe.map Tuple.first |> Maybe.withDefault startDate

            startX = dayToX yMinK firstDay
            endX = dayToX yMinK (lastDay + 1)

            -- Build full polygon: start at baseline, go up and across, come back to baseline
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


{-| Draw a step line (for earned money and debt lines).
    Steps occur at day boundaries.

    Handles gaps: if there's a gap between days, extends the previous value
    horizontally until the next data point's day, then steps vertically.
-}
drawStepLine : Float -> List ( Int, Float ) -> String -> Svg msg
drawStepLine yMinK dayValues color =
    if List.isEmpty dayValues then
        g [] []
    else
        let
            -- Build step points, handling gaps between days
            buildPoints : Maybe ( Int, Float ) -> List ( Int, Float ) -> List String
            buildPoints prevMaybe pts =
                case pts of
                    [] -> []
                    ( day, val ) :: rest ->
                        let
                            x1 = dayToX yMinK day
                            x2 = dayToX yMinK (day + 1)
                            y = valueToY yMinK val

                            -- If there's a gap from previous day, extend previous value to this day's start
                            gapPoints =
                                case prevMaybe of
                                    Just ( prevDay, prevVal ) ->
                                        if day > prevDay + 1 then
                                            -- There's a gap: extend previous value to start of this day
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


{-| Draw orange vertical segments showing daily pay earned.

For each day, draws a thick orange vertical line from the previous day's
earnedMoney to (previousEarnedMoney + dailyPayEarned). This shows where
the blue line *would be* if no money was spent that day.

Arguments:
- yMinK: Y axis minimum (for coordinate transforms)
- dayDataList: list of DayData records
-}
drawDailyPaySegments : Float -> List DayData -> Svg msg
drawDailyPaySegments yMinK dayDataList =
    let
        -- Build pairs of (previousEarnedMoney, currentDayData)
        -- We need previous day's earnedMoney to know where to start the segment
        buildSegments : Maybe DayData -> List DayData -> List (Svg msg)
        buildSegments prevMaybe remaining =
            case remaining of
                [] ->
                    []

                current :: rest ->
                    let
                        -- Get previous earned money (or 0 if first day)
                        prevEarned =
                            case prevMaybe of
                                Just prev ->
                                    -- If there's a gap, we'd extend prev value, so use that
                                    prev.earnedMoney

                                Nothing ->
                                    -- First data point - no previous, start from checking
                                    -- Actually for first day, the "step" is from 0 or the day's own checking
                                    -- Let's use the current day's checking as baseline (what we had before pay)
                                    current.checking

                        -- Only draw if there's actual daily pay
                        segment =
                            if current.dailyPayEarned > 0 then
                                let
                                    x = dayToX yMinK current.day
                                    yBottom = valueToY yMinK prevEarned
                                    yTop = valueToY yMinK (prevEarned + current.dailyPayEarned)
                                    rectWidth = 5
                                    rectHeight = yBottom - yTop  -- yBottom > yTop in SVG coords
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


{-| Draw note annotations - colored dots with angled text above the highest line value.
-}
drawNotes : Float -> List DayData -> Svg msg
drawNotes yMinK dayDataList =
    let
        -- Get colors for note types (dot color and slightly different text color)
        noteColors : NoteColor -> { dot : String, text : String }
        noteColors color =
            case color of
                NoteGreen -> { dot = "#22c55e", text = "#16a34a" }  -- green-500, green-600
                NoteBlue -> { dot = "#3b82f6", text = "#2563eb" }   -- blue-500, blue-600
                NoteRed -> { dot = "#ef4444", text = "#dc2626" }    -- red-500, red-600
                NoteYellow -> { dot = "#eab308", text = "#ca8a04" } -- yellow-500, yellow-600
                NoColor -> { dot = "#9ca3af", text = "#6b7280" }    -- gray-400, gray-500

        drawNote : DayData -> List (Svg msg)
        drawNote dayData =
            case dayData.note of
                Nothing -> []
                Just noteInfo ->
                    let
                        colors = noteColors noteInfo.color

                        -- Position at center of the day
                        x = dayToX yMinK dayData.day + (dayToX yMinK (dayData.day + 1) - dayToX yMinK dayData.day) / 2

                        -- Find highest value for this day
                        highestValue = max dayData.earnedMoney (max dayData.checking dayData.personalDebt)

                        -- Position dot above the highest line with some padding
                        dotY = valueToY yMinK (highestValue + 0.5)  -- 0.5k ($500) above
                        dotRadius = 6

                        -- Text starts from dot, angled 45° up-right
                        textX = x + 10
                        textY = dotY - 10
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
                        , SA.fill colors.text
                        , SA.fontSize "14"
                        , SA.fontFamily "sans-serif"
                        , SA.fontWeight "bold"
                        , SA.transform ("rotate(-45 " ++ String.fromFloat textX ++ " " ++ String.fromFloat textY ++ ")")
                        ]
                        [ Svg.text noteInfo.text ]
                    ]
    in
    g [] (List.concatMap drawNote dayDataList)


-- AXES

drawXAxis : Float -> Svg msg
drawXAxis yMinK =
    let
        y0 = valueToY yMinK 0

        -- Main axis line
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

        -- Ticks and labels for each day
        dayTicks =
            List.range startDate endDate
                |> List.map (\day ->
                    let
                        x = dayToX yMinK day
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
                            [ SA.x (String.fromFloat (x + (dayToX yMinK (day + 1) - x) / 2))
                            , SA.y (String.fromFloat (y0 + 28))
                            , SA.fill colorText
                            , SA.fontSize "16"
                            , SA.textAnchor "middle"
                            ]
                            [ Svg.text (dayLabel day) ]
                        ]
                )
    in
    g [] (axisLine :: dayTicks)


drawYAxis : Float -> Svg msg
drawYAxis yMinK =
    let
        -- Tick marks at every $1k
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


-- GRID LINES

{-| Draw grid lines:
    - Faint horizontal lines every $1k
    - Thin vertical lines at day boundaries
    - Thick vertical lines at week boundaries (Sundays)
-}
drawGridLines : Float -> Svg msg
drawGridLines yMinK =
    let
        -- Horizontal grid lines every $1k
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

        -- Vertical grid lines at day boundaries
        -- Check if day is a Sunday (week boundary) for thicker line
        -- 2000-01-01 was a Saturday (6), so 1=Sun, 8=Sun, etc.
        -- dayOfWeek: 0=Sat, 1=Sun, 2=Mon, etc.
        dayLines =
            List.range startDate (endDate + 1)
                |> List.map (\day ->
                    let
                        x = dayToX yMinK day
                        dayOfWeek = modBy 7 day  -- 0=Sat, 1=Sun, 2=Mon, etc.
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


-- CLOCK

alaskaZone : Time.Zone
alaskaZone =
    Time.customZone (-9 * 60) []

formatMilitaryTime : Time.Zone -> Time.Posix -> String
formatMilitaryTime zone time =
    let
        hour = Time.toHour zone time
        minute = Time.toMinute zone time
        second = Time.toSecond zone time
        pad n = if n < 10 then "0" ++ String.fromInt n else String.fromInt n
    in
    pad hour ++ ":" ++ pad minute ++ ":" ++ pad second


-- MAIN GRAPH VIEW

viewGraph : List Entry -> Time.Posix -> Maybe Weather -> Element msg
viewGraph entries currentTime maybeWeather =
    let
        dayData = buildDayData entries

        -- Get credit limit from most recent entry for Y axis scaling
        creditLimitK =
            entries
                |> List.reverse
                |> List.head
                |> Maybe.map (\e -> e.creditLimit / 1000)
                |> Maybe.withDefault 0.5

        -- Y min is negative credit limit
        yMinK = -creditLimitK

        -- Checking values (green filled polygon from 0 baseline)
        checkingValues =
            dayData
                |> List.map (\d -> ( d.day, d.checking ))

        checkingPolygon = drawStepPolygon yMinK 0 checkingValues colorGreen

        -- Credit drawn values (yellow filled polygon going DOWN from 0)
        creditValues =
            dayData
                |> List.map (\d -> ( d.day, -d.creditDrawn ))

        creditPolygon = drawStepPolygon yMinK 0 creditValues colorYellow

        -- Orange shadow segments showing daily pay earned (behind the blue line)
        dailyPaySegments = drawDailyPaySegments yMinK dayData

        -- Earned money line (cerulean step line)
        earnedValues =
            dayData
                |> List.map (\d -> ( d.day, d.earnedMoney ))

        earnedLine = drawStepLine yMinK earnedValues colorEarnedLine

        -- Personal debt line (red step line)
        debtValues =
            dayData
                |> List.map (\d -> ( d.day, d.personalDebt ))

        debtLine = drawStepLine yMinK debtValues colorRed

        -- End labels for most recent values (positioned just right of last data point)
        -- Labels are sorted by Y position and pushed down if they would overlap
        endLabels =
            case List.reverse dayData of
                latest :: _ ->
                    let
                        -- Position label just after the last day's bar ends
                        labelX = dayToX yMinK (latest.day + 1) + 10
                        labelHeight = 20  -- Approximate height for spacing

                        -- Build list of labels with their desired Y positions
                        -- Filter out labels when their value is zero
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

                        -- Sort by desired Y (top to bottom in SVG coordinates)
                        sortedLabels = List.sortBy .desiredY rawLabels

                        -- Push labels down if they would overlap
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

        -- Clock overlay using Elm UI
        timeStr = formatMilitaryTime alaskaZone currentTime

        weatherStr =
            case maybeWeather of
                Just w ->
                    String.fromInt w.lowF ++ "° - " ++ String.fromInt w.highF ++ "°"

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
                    [ -- Background
                      rect
                        [ SA.x "0"
                        , SA.y "0"
                        , SA.width (String.fromFloat graphWidth)
                        , SA.height (String.fromFloat graphHeight)
                        , SA.fill colorBackground
                        ]
                        []
                    , -- Grid lines (drawn first, behind data)
                      drawGridLines yMinK
                    , -- Data
                      checkingPolygon
                    , creditPolygon
                    , dailyPaySegments  -- Orange segments behind blue line
                    , earnedLine
                    , debtLine
                    , -- Axes and labels
                      drawYAxis yMinK
                    , drawXAxis yMinK
                    , -- End labels
                      endLabels
                    , -- Notes (on top of everything)
                      drawNotes yMinK dayData
                    ]
    in
    el [ inFront clockOverlay ] svgGraph


-- MINI GRAPH (for entry page)

viewMiniGraph : List Entry -> Element msg
viewMiniGraph entries =
    let
        -- Smaller dimensions for mini graph
        miniWidth = 800
        miniHeight = 200
        miniMarginLeft = 50
        miniMarginRight = 60
        miniMarginTop = 15
        miniMarginBottom = 30
        miniPlotWidth = miniWidth - miniMarginLeft - miniMarginRight
        miniPlotHeight = miniHeight - miniMarginTop - miniMarginBottom

        dayData = buildDayData entries

        -- Get credit limit from most recent entry for Y axis scaling
        creditLimitK =
            entries
                |> List.reverse
                |> List.head
                |> Maybe.map (\e -> e.creditLimit / 1000)
                |> Maybe.withDefault 0.5

        yMinK = -creditLimitK

        -- Coordinate transform functions for mini graph
        miniDayToX day =
            let
                dayOffset = toFloat (day - startDate)
                totalDaysFloat = toFloat totalDays
            in
            miniMarginLeft + (dayOffset / totalDaysFloat) * miniPlotWidth

        miniValueToY valueK =
            let
                range = yMax - yMinK
                normalized = (valueK - yMinK) / range
            in
            miniMarginTop + miniPlotHeight - (normalized * miniPlotHeight)

        -- Build step polygon for mini graph
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

        -- Build step line for mini graph
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

        -- Data layers
        checkingValues = List.map (\d -> ( d.day, d.checking )) dayData
        creditValues = List.map (\d -> ( d.day, -d.creditDrawn )) dayData
        earnedValues = List.map (\d -> ( d.day, d.earnedMoney )) dayData
        debtValues = List.map (\d -> ( d.day, d.personalDebt )) dayData

        -- Zero line
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
            [ -- Background
              rect
                [ SA.x "0"
                , SA.y "0"
                , SA.width (String.fromFloat miniWidth)
                , SA.height (String.fromFloat miniHeight)
                , SA.fill colorBackground
                , SA.rx "8"
                ]
                []
            , -- Data
              miniStepPolygon 0 checkingValues colorGreen
            , miniStepPolygon 0 creditValues colorYellow
            , miniStepLine earnedValues colorEarnedLine
            , miniStepLine debtValues colorRed
            , -- Zero line
              zeroLine
            ]
