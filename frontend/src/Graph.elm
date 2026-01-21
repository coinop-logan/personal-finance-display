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
marginBottom = 50

plotWidth : Float
plotWidth = graphWidth - marginLeft - marginRight

plotHeight : Float
plotHeight = graphHeight - marginTop - marginBottom

startDate : Int
startDate = dateToDays "2025-12-29"

endDate : Int
endDate = dateToDays "2026-01-31"

totalDays : Int
totalDays = endDate - startDate

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


dayToX : Float -> Int -> Float
dayToX yMinK day =
    let
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


dayLabel : Int -> String
dayLabel day =
    let
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

        dateStr = Calculations.daysToDateString day
        dayNum =
            String.split "-" dateStr
                |> List.drop 2
                |> List.head
                |> Maybe.andThen String.toInt
                |> Maybe.withDefault 0
    in
    weekdayLetter ++ String.fromInt dayNum


drawStepPolygon : Float -> Float -> List ( Int, Float ) -> String -> Svg msg
drawStepPolygon yMinK baseline dayValues color =
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
                            x1 = dayToX yMinK day
                            x2 = dayToX yMinK (day + 1)
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

            startX = dayToX yMinK firstDay
            endX = dayToX yMinK (lastDay + 1)

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


drawStepLine : Float -> List ( Int, Float ) -> String -> Svg msg
drawStepLine yMinK dayValues color =
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
                            x1 = dayToX yMinK day
                            x2 = dayToX yMinK (day + 1)
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


drawDailyPaySegments : Float -> List DayData -> Svg msg
drawDailyPaySegments yMinK dayDataList =
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
                                    x = dayToX yMinK current.day
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


drawNotes : Float -> List DayData -> Svg msg
drawNotes yMinK dayDataList =
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

                        x = dayToX yMinK dayData.day + (dayToX yMinK (dayData.day + 1) - dayToX yMinK dayData.day) / 2

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


drawXAxis : Float -> Svg msg
drawXAxis yMinK =
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


drawGridLines : Float -> Svg msg
drawGridLines yMinK =
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
            List.range startDate (endDate + 1)
                |> List.map (\day ->
                    let
                        x = dayToX yMinK day
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

        checkingPolygon = drawStepPolygon yMinK 0 checkingValues colorGreen

        creditValues =
            dayData
                |> List.map (\d -> ( d.day, -d.creditDrawn ))

        creditPolygon = drawStepPolygon yMinK 0 creditValues colorYellow

        dailyPaySegments = drawDailyPaySegments yMinK dayData

        earnedValues =
            dayData
                |> List.map (\d -> ( d.day, d.earnedMoney ))

        earnedLine = drawStepLine yMinK earnedValues colorEarnedLine

        debtValues =
            dayData
                |> List.map (\d -> ( d.day, d.personalDebt ))

        debtLine = drawStepLine yMinK debtValues colorRed

        endLabels =
            case List.reverse dayData of
                latest :: _ ->
                    let
                        labelX = dayToX yMinK (latest.day + 1) + 10
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
                    , drawGridLines yMinK
                    , checkingPolygon
                    , creditPolygon
                    , dailyPaySegments
                    , earnedLine
                    , debtLine
                    , drawYAxis yMinK
                    , drawXAxis yMinK
                    , endLabels
                    , drawNotes yMinK dayData
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
                totalDaysFloat = toFloat totalDays
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
