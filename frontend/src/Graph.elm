module Graph exposing (viewGraph)

import Api.Types exposing (Entry)
import Calculations exposing (dateToDays, incomingPayForEntry)
import Element exposing (Element, html)
import Svg exposing (Svg, svg, rect, line, text_, g, polyline)
import Svg.Attributes as SA


-- CONSTANTS

graphWidth : Float
graphWidth = 800

graphHeight : Float
graphHeight = 400

marginLeft : Float
marginLeft = 50

marginRight : Float
marginRight = 80

marginTop : Float
marginTop = 20

marginBottom : Float
marginBottom = 30

plotWidth : Float
plotWidth = graphWidth - marginLeft - marginRight

plotHeight : Float
plotHeight = graphHeight - marginTop - marginBottom

-- Date range: 2025-12-23 to 2026-01-31
startDate : Int
startDate = dateToDays "2025-12-23"

endDate : Int
endDate = dateToDays "2026-01-31"

totalDays : Int
totalDays = endDate - startDate

-- Y axis: from -creditLimit (we'll use -0.5k as default) to 20k
yMin : Float
yMin = -0.5  -- in thousands

yMax : Float
yMax = 20.0  -- in thousands


-- COLORS

colorGreen : String
colorGreen = "#4ade80"

colorCerulean : String
colorCerulean = "#00acee"

colorYellow : String
colorYellow = "#fbbf24"

colorRed : String
colorRed = "#ff6b6b"

colorText : String
colorText = "#888"

colorAxis : String
colorAxis = "#555"

colorBackground : String
colorBackground = "#252542"


-- GRAPH DATA

type alias DayData =
    { day : Int
    , checking : Float  -- in k
    , earnedMoney : Float  -- checking + incoming pay, in k
    , creditDrawn : Float  -- credit limit - credit available, in k
    , personalDebt : Float  -- in k
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
            }
    in
    entriesByDay
        |> List.map (\( day, entry ) -> buildForDay day entry)


-- COORDINATE TRANSFORMS

dayToX : Int -> Float
dayToX day =
    let
        dayOffset = toFloat (day - startDate)
        totalDaysFloat = toFloat totalDays
    in
    marginLeft + (dayOffset / totalDaysFloat) * plotWidth

valueToY : Float -> Float
valueToY valueK =
    -- Y axis is inverted in SVG (0 at top)
    let
        range = yMax - yMin
        normalized = (valueK - yMin) / range
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

drawBar : Float -> Float -> Float -> Float -> String -> Svg msg
drawBar x1 width y1 y2 color =
    rect
        [ SA.x (String.fromFloat x1)
        , SA.y (String.fromFloat (min y1 y2))
        , SA.width (String.fromFloat width)
        , SA.height (String.fromFloat (abs (y2 - y1)))
        , SA.fill color
        ]
        []


drawStepLine : List ( Float, Float ) -> String -> Svg msg
drawStepLine points color =
    if List.isEmpty points then
        g [] []
    else
        let
            -- Build step function path: for each point, draw horizontal then vertical
            buildSteps : List ( Float, Float ) -> List ( Float, Float )
            buildSteps pts =
                case pts of
                    [] -> []
                    [ single ] -> [ single ]
                    ( x1, y1 ) :: ( x2, y2 ) :: rest ->
                        ( x1, y1 ) :: ( x2, y1 ) :: buildSteps (( x2, y2 ) :: rest)

            steppedPoints = buildSteps points

            pointsStr =
                steppedPoints
                    |> List.map (\( x, y ) -> String.fromFloat x ++ "," ++ String.fromFloat y)
                    |> String.join " "
        in
        polyline
            [ SA.points pointsStr
            , SA.fill "none"
            , SA.stroke color
            , SA.strokeWidth "2"
            ]
            []


-- AXES

drawXAxis : Svg msg
drawXAxis =
    let
        y0 = valueToY 0

        -- Main axis line
        axisLine =
            line
                [ SA.x1 (String.fromFloat marginLeft)
                , SA.y1 (String.fromFloat y0)
                , SA.x2 (String.fromFloat (graphWidth - marginRight))
                , SA.y2 (String.fromFloat y0)
                , SA.stroke colorAxis
                , SA.strokeWidth "1"
                ]
                []

        -- Ticks and labels for each day
        dayTicks =
            List.range startDate endDate
                |> List.map (\day ->
                    let
                        x = dayToX day
                    in
                    g []
                        [ line
                            [ SA.x1 (String.fromFloat x)
                            , SA.y1 (String.fromFloat y0)
                            , SA.x2 (String.fromFloat x)
                            , SA.y2 (String.fromFloat (y0 + 5))
                            , SA.stroke colorAxis
                            , SA.strokeWidth "1"
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat (x + (dayToX (day + 1) - x) / 2))
                            , SA.y (String.fromFloat (y0 + 18))
                            , SA.fill colorText
                            , SA.fontSize "9"
                            , SA.textAnchor "middle"
                            ]
                            [ Svg.text (dayLabel day) ]
                        ]
                )
    in
    g [] (axisLine :: dayTicks)


drawYAxis : Float -> Svg msg
drawYAxis creditLimitK =
    let
        actualYMin = -(abs creditLimitK)

        -- Tick marks at every $5k
        tickValues =
            List.range (ceiling (actualYMin / 5)) (floor (yMax / 5))
                |> List.map (\n -> toFloat n * 5)

        ticks =
            tickValues
                |> List.map (\val ->
                    let
                        y = valueToY val
                    in
                    g []
                        [ line
                            [ SA.x1 (String.fromFloat (marginLeft - 5))
                            , SA.y1 (String.fromFloat y)
                            , SA.x2 (String.fromFloat marginLeft)
                            , SA.y2 (String.fromFloat y)
                            , SA.stroke colorAxis
                            , SA.strokeWidth "1"
                            ]
                            []
                        , text_
                            [ SA.x (String.fromFloat (marginLeft - 8))
                            , SA.y (String.fromFloat (y + 3))
                            , SA.fill colorText
                            , SA.fontSize "10"
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
                , SA.strokeWidth "1"
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

        barWidth = plotWidth / toFloat totalDays * 0.6

        -- Checking bars (green, solid)
        checkingBars =
            dayData
                |> List.map (\d ->
                    let
                        x = dayToX d.day
                        y0 = valueToY 0
                        yVal = valueToY d.checking
                    in
                    drawBar x barWidth y0 yVal colorGreen
                )

        -- Credit drawn bars (yellow, going DOWN from x-axis)
        creditBars =
            dayData
                |> List.map (\d ->
                    let
                        x = dayToX d.day + barWidth * 0.1  -- Slight offset
                        y0 = valueToY 0
                        yVal = valueToY (-d.creditDrawn)  -- Negative to go below axis
                    in
                    drawBar x (barWidth * 0.8) y0 yVal colorYellow
                )

        -- Earned money line (cerulean step line)
        earnedMoneyPoints =
            dayData
                |> List.map (\d -> ( dayToX d.day, valueToY d.earnedMoney ))

        -- Extend to end of day range
        earnedMoneyPointsExtended =
            case List.reverse earnedMoneyPoints of
                ( lastX, lastY ) :: rest ->
                    List.reverse rest ++ [ ( lastX, lastY ), ( dayToX endDate, lastY ) ]
                _ ->
                    earnedMoneyPoints

        earnedLine = drawStepLine earnedMoneyPointsExtended colorCerulean

        -- Personal debt line (red step line)
        debtPoints =
            dayData
                |> List.map (\d -> ( dayToX d.day, valueToY d.personalDebt ))

        debtPointsExtended =
            case List.reverse debtPoints of
                ( lastX, lastY ) :: rest ->
                    List.reverse rest ++ [ ( lastX, lastY ), ( dayToX endDate, lastY ) ]
                _ ->
                    debtPoints

        debtLine = drawStepLine debtPointsExtended colorRed

        -- End labels for most recent values
        endLabels =
            case List.reverse dayData of
                latest :: _ ->
                    let
                        labelX = graphWidth - marginRight + 5
                    in
                    g []
                        [ text_
                            [ SA.x (String.fromFloat labelX)
                            , SA.y (String.fromFloat (valueToY latest.checking))
                            , SA.fill colorGreen
                            , SA.fontSize "11"
                            , SA.dominantBaseline "middle"
                            ]
                            [ Svg.text (formatK latest.checking) ]
                        , text_
                            [ SA.x (String.fromFloat labelX)
                            , SA.y (String.fromFloat (valueToY latest.earnedMoney))
                            , SA.fill colorCerulean
                            , SA.fontSize "11"
                            , SA.dominantBaseline "middle"
                            ]
                            [ Svg.text (formatK latest.earnedMoney) ]
                        , text_
                            [ SA.x (String.fromFloat labelX)
                            , SA.y (String.fromFloat (valueToY (-latest.creditDrawn)))
                            , SA.fill colorYellow
                            , SA.fontSize "11"
                            , SA.dominantBaseline "middle"
                            ]
                            [ Svg.text (formatK latest.creditDrawn) ]
                        , text_
                            [ SA.x (String.fromFloat labelX)
                            , SA.y (String.fromFloat (valueToY latest.personalDebt))
                            , SA.fill colorRed
                            , SA.fontSize "11"
                            , SA.dominantBaseline "middle"
                            ]
                            [ Svg.text (formatK latest.personalDebt) ]
                        ]
                _ ->
                    g [] []
    in
    html <|
        svg
            [ SA.width (String.fromFloat graphWidth)
            , SA.height (String.fromFloat graphHeight)
            , SA.viewBox ("0 0 " ++ String.fromFloat graphWidth ++ " " ++ String.fromFloat graphHeight)
            ]
            [ -- Background
              rect
                [ SA.x "0"
                , SA.y "0"
                , SA.width (String.fromFloat graphWidth)
                , SA.height (String.fromFloat graphHeight)
                , SA.fill colorBackground
                , SA.rx "12"
                ]
                []
            , -- Axes
              drawYAxis creditLimitK
            , drawXAxis
            , -- Data
              g [] checkingBars
            , g [] creditBars
            , earnedLine
            , debtLine
            , endLabels
            ]
