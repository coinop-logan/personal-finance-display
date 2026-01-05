module Graph exposing (viewGraph, viewMiniGraph)

import Api.Types exposing (Entry)
import Calculations exposing (dateToDays, incomingPayForEntry)
import Element exposing (Element, html)
import Svg exposing (Svg, svg, rect, line, text_, g, polygon, polyline)
import Svg.Attributes as SA


-- CONSTANTS (1920x1080 full HD)

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

-- Date range: 2025-12-20 to 2026-01-31
startDate : Int
startDate = dateToDays "2025-12-20"

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


-- GRAPH DATA

type alias DayData =
    { day : Int
    , checking : Float  -- in k
    , earnedMoney : Float  -- checking + incoming pay, in k
    , creditDrawn : Float  -- credit limit - credit available, in k
    , personalDebt : Float  -- in k
    , creditLimit : Float  -- in k
    }


buildDayData : List Entry -> List DayData
buildDayData entries =
    let
        entriesByDay =
            entries
                |> List.map (\e -> ( dateToDays e.date, e ))
                |> List.sortBy Tuple.first

        buildForDay : Int -> Entry -> DayData
        buildForDay day entry =
            let
                incomingPay = incomingPayForEntry entry entries
            in
            { day = day
            , checking = entry.checking / 1000
            , earnedMoney = (entry.checking + incomingPay) / 1000
            , creditDrawn = (entry.creditLimit - entry.creditAvailable) / 1000
            , personalDebt = entry.personalDebt / 1000
            , creditLimit = entry.creditLimit / 1000
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
        -- Tick marks at every $5k
        tickValues =
            List.range (ceiling (yMinK / 5)) (floor (yMax / 5))
                |> List.map (\n -> toFloat n * 5)

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


-- MAIN GRAPH VIEW

viewGraph : List Entry -> Element msg
viewGraph entries =
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
    in
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
            , -- Data (drawn first so axes render on top)
              checkingPolygon
            , creditPolygon
            , earnedLine
            , debtLine
            , -- Axes and labels (second to last)
              drawYAxis yMinK
            , drawXAxis yMinK
            , -- End labels (last, so they're always visible)
              endLabels
            ]


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
