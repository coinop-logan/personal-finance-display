module Main exposing (main)

import Api.Types exposing (Entry, NewEntry, entryDecoder, newEntryEncoder)
import Browser
import Browser.Navigation as Nav
import Html exposing (Html, div, text, h1, h2, p, input, button, label, span)
import Html.Attributes exposing (style, type_, value, placeholder, step, id)
import Html.Events exposing (onInput, onClick)
import Http
import Json.Decode as Decode exposing (Decoder)
import Url exposing (Url)


-- MAIN

main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


-- MODEL

type alias Flags =
    { today : String }

type alias EntryForm =
    { dateDays : Int  -- Days since epoch (2000-01-01 = 0)
    , checking : String
    , creditAvailable : String
    , hoursWorked : String
    , payPerHour : String
    , otherIncoming : String
    , personalDebt : String
    , note : String
    }

type Page
    = GraphPage
    | EntryPage

type alias Model =
    { entries : List Entry
    , error : Maybe String
    , loading : Bool
    , page : Page
    , form : EntryForm
    , submitting : Bool
    , key : Nav.Key
    , todayDays : Int
    }

emptyForm : Int -> EntryForm
emptyForm todayDays =
    { dateDays = todayDays
    , checking = ""
    , creditAvailable = ""
    , hoursWorked = ""
    , payPerHour = ""
    , otherIncoming = ""
    , personalDebt = ""
    , note = ""
    }


formFromLastEntry : Int -> Entry -> EntryForm
formFromLastEntry todayDays entry =
    { dateDays = todayDays
    , checking = String.fromFloat entry.checking
    , creditAvailable = String.fromFloat entry.creditAvailable
    , hoursWorked = ""  -- Don't carry over hours, default to empty (0)
    , payPerHour = String.fromFloat entry.payPerHour
    , otherIncoming = String.fromFloat entry.otherIncoming
    , personalDebt = String.fromFloat entry.personalDebt
    , note = ""
    }


formFromEntries : Int -> List Entry -> EntryForm
formFromEntries todayDays entries =
    case List.reverse entries |> List.head of
        Just lastEntry ->
            formFromLastEntry todayDays lastEntry

        Nothing ->
            emptyForm todayDays


-- Convert date string "YYYY-MM-DD" to days since epoch
dateToDays : String -> Int
dateToDays dateStr =
    case parseDate dateStr of
        Just ( year, month, day ) ->
            daysSinceEpoch year month day

        Nothing ->
            0  -- fallback, shouldn't happen with valid input


-- Convert days since epoch back to "YYYY-MM-DD" string
daysToDateString : Int -> String
daysToDateString days =
    let
        ( year, month, day ) = dateFromDays days
    in
    formatDate year month day

urlToPage : Url -> Page
urlToPage url =
    if String.contains "/entry" url.path then
        EntryPage
    else
        GraphPage

init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        todayDays = dateToDays flags.today
    in
    ( { entries = []
      , error = Nothing
      , loading = True
      , page = urlToPage url
      , form = emptyForm todayDays
      , submitting = False
      , key = key
      , todayDays = todayDays
      }
    , fetchData
    )


-- UPDATE

type Msg
    = GotData (Result Http.Error (List Entry))
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | UpdateForm FormField String
    | AdjustDate Int
    | SubmitEntry
    | SubmitResult (Result Http.Error ())
    | DeleteEntry Int
    | DeleteResult (Result Http.Error ())

type FormField
    = Checking
    | CreditAvailable
    | HoursWorked
    | PayPerHour
    | OtherIncoming
    | PersonalDebt
    | Note

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotData result ->
            case result of
                Ok entries ->
                    let
                        -- Only populate form from entries on initial load (when form is empty)
                        updatedForm =
                            if model.form.checking == "" then
                                formFromEntries model.todayDays entries
                            else
                                model.form
                    in
                    ( { model | entries = entries, loading = False, error = Nothing, form = updatedForm }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | loading = False, error = Just (httpErrorToString err) }
                    , Cmd.none
                    )

        UrlChanged url ->
            ( { model | page = urlToPage url }, Cmd.none )

        LinkClicked request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UpdateForm field val ->
            let
                f = model.form
                newForm =
                    case field of
                        Checking -> { f | checking = val }
                        CreditAvailable -> { f | creditAvailable = val }
                        HoursWorked -> { f | hoursWorked = val }
                        PayPerHour -> { f | payPerHour = val }
                        OtherIncoming -> { f | otherIncoming = val }
                        PersonalDebt -> { f | personalDebt = val }
                        Note -> { f | note = val }
            in
            ( { model | form = newForm }, Cmd.none )

        AdjustDate delta ->
            let
                f = model.form
            in
            ( { model | form = { f | dateDays = f.dateDays + delta } }, Cmd.none )

        SubmitEntry ->
            let
                f = model.form
                dateStr = daysToDateString f.dateDays
                maybeEntry =
                    Maybe.map2
                        (\checking creditAvailable ->
                            { date = dateStr
                            , checking = checking
                            , creditAvailable = creditAvailable
                            , hoursWorked = String.toFloat f.hoursWorked |> Maybe.withDefault 0
                            , payPerHour = String.toFloat f.payPerHour |> Maybe.withDefault 0
                            , otherIncoming = String.toFloat f.otherIncoming |> Maybe.withDefault 0
                            , personalDebt = String.toFloat f.personalDebt |> Maybe.withDefault 0
                            , note = f.note
                            }
                        )
                        (String.toFloat f.checking)
                        (String.toFloat f.creditAvailable)
            in
            case maybeEntry of
                Just newEntry ->
                    ( { model | submitting = True, error = Nothing }
                    , submitEntry newEntry
                    )

                Nothing ->
                    ( { model | error = Just "Checking and Credit Available are required" }
                    , Cmd.none
                    )

        SubmitResult result ->
            case result of
                Ok _ ->
                    -- Reset form to empty so GotData will repopulate from new entry list
                    ( { model
                        | submitting = False
                        , form = emptyForm model.todayDays
                      }
                    , fetchData
                    )

                Err err ->
                    ( { model
                        | submitting = False
                        , error = Just (httpErrorToString err)
                      }
                    , Cmd.none
                    )

        DeleteEntry entryId ->
            ( model, deleteEntry entryId )

        DeleteResult result ->
            case result of
                Ok _ ->
                    ( model, fetchData )

                Err err ->
                    ( { model | error = Just (httpErrorToString err) }, Cmd.none )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus code ->
            "Server error: " ++ String.fromInt code

        Http.BadBody body ->
            "Bad response: " ++ body


-- DATE HELPERS

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


-- Days since epoch (2000-01-01 = day 0)
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
        -- Approximate year
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


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


-- HTTP

fetchData : Cmd Msg
fetchData =
    Http.get
        { url = "/api/data"
        , expect = Http.expectJson GotData dataDecoder
        }

submitEntry : NewEntry -> Cmd Msg
submitEntry newEntry =
    Http.post
        { url = "/api/entry"
        , body = Http.jsonBody (newEntryEncoder newEntry)
        , expect = Http.expectWhatever SubmitResult
        }

deleteEntry : Int -> Cmd Msg
deleteEntry entryId =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/entry/" ++ String.fromInt entryId
        , body = Http.emptyBody
        , expect = Http.expectWhatever DeleteResult
        , timeout = Nothing
        , tracker = Nothing
        }

dataDecoder : Decoder (List Entry)
dataDecoder =
    Decode.list entryDecoder


-- VIEW

view : Model -> Browser.Document Msg
view model =
    { title = "Finance Tracker"
    , body = [ viewBody model ]
    }

viewBody : Model -> Html Msg
viewBody model =
    div
        [ style "background-color" "#1a1a2e"
        , style "color" "#eee"
        , style "min-height" "100vh"
        , style "padding" "20px"
        , style "font-family" "system-ui, -apple-system, sans-serif"
        , style "box-sizing" "border-box"
        ]
        [ case model.page of
            GraphPage ->
                viewGraphPage model

            EntryPage ->
                viewEntryPage model
        ]

viewGraphPage : Model -> Html Msg
viewGraphPage model =
    div []
        [ h1
            [ style "margin" "0 0 20px 0"
            , style "font-weight" "300"
            , style "font-size" "1.5em"
            ]
            [ text "Finance Tracker" ]
        , viewGraphPlaceholder
        , viewMessageForMom
        ]

viewEntryPage : Model -> Html Msg
viewEntryPage model =
    div []
        [ h1
            [ style "margin" "0 0 20px 0"
            , style "font-weight" "300"
            , style "font-size" "1.5em"
            ]
            [ text "Data Entry" ]
        , if model.loading then
            p [] [ text "Loading..." ]
          else
            div []
                [ viewEntryForm model
                , viewRecentEntries model.entries
                , viewCalculated model.entries
                ]
        , case model.error of
            Just err ->
                p [ style "color" "#ff6b6b", style "margin-top" "20px" ] [ text err ]
            Nothing ->
                text ""
        ]

viewEntryForm : Model -> Html Msg
viewEntryForm model =
    div
        [ style "background" "#252542"
        , style "padding" "15px"
        , style "border-radius" "12px"
        , style "margin-bottom" "20px"
        ]
        [ div
            [ style "display" "flex"
            , style "flex-wrap" "wrap"
            , style "gap" "10px"
            , style "align-items" "flex-end"
            ]
            [ viewDatePicker model.form.dateDays
            , viewCompactField "Checking" "number" model.form.checking (UpdateForm Checking) "90px"
            , viewCompactField "Credit Avail" "number" model.form.creditAvailable (UpdateForm CreditAvailable) "90px"
            , viewCompactField "Hours Today" "number" model.form.hoursWorked (UpdateForm HoursWorked) "80px"
            , viewCompactField "$/hr" "number" model.form.payPerHour (UpdateForm PayPerHour) "70px"
            , viewCompactField "Other $" "number" model.form.otherIncoming (UpdateForm OtherIncoming) "80px"
            , viewCompactField "Pers. Debt" "number" model.form.personalDebt (UpdateForm PersonalDebt) "80px"
            , viewCompactField "Note" "text" model.form.note (UpdateForm Note) "120px"
            , button
                [ onClick SubmitEntry
                , style "padding" "8px 20px"
                , style "background" "linear-gradient(to right, #4facfe, #00f2fe)"
                , style "border" "none"
                , style "border-radius" "6px"
                , style "color" "#1a1a2e"
                , style "font-size" "1.2em"
                , style "font-weight" "600"
                , style "cursor" "pointer"
                , style "height" "36px"
                ]
                [ text (if model.submitting then "..." else "+") ]
            ]
        ]

viewDatePicker : Int -> Html Msg
viewDatePicker dateDays =
    let
        dateStr = daysToDateString dateDays
    in
    div [ style "display" "flex", style "flex-direction" "column" ]
        [ label
            [ style "font-size" "0.7em"
            , style "color" "#888"
            , style "margin-bottom" "3px"
            ]
            [ text "Date" ]
        , div [ style "display" "flex", style "align-items" "center", style "gap" "2px" ]
            [ span
                [ style "padding" "8px 12px"
                , style "background" "#1a1a2e"
                , style "border" "1px solid #333"
                , style "border-radius" "4px 0 0 4px"
                , style "color" "#eee"
                , style "font-size" "0.9em"
                , style "min-width" "100px"
                , style "text-align" "center"
                ]
                [ text dateStr ]
            , div [ style "display" "flex", style "flex-direction" "column" ]
                [ button
                    [ onClick (AdjustDate 1)
                    , style "padding" "2px 8px"
                    , style "background" "#1a1a2e"
                    , style "border" "1px solid #333"
                    , style "border-radius" "0 4px 0 0"
                    , style "color" "#eee"
                    , style "font-size" "0.7em"
                    , style "cursor" "pointer"
                    , style "line-height" "1"
                    ]
                    [ text "▲" ]
                , button
                    [ onClick (AdjustDate -1)
                    , style "padding" "2px 8px"
                    , style "background" "#1a1a2e"
                    , style "border" "1px solid #333"
                    , style "border-top" "none"
                    , style "border-radius" "0 0 4px 0"
                    , style "color" "#eee"
                    , style "font-size" "0.7em"
                    , style "cursor" "pointer"
                    , style "line-height" "1"
                    ]
                    [ text "▼" ]
                ]
            ]
        ]


viewCompactField : String -> String -> String -> (String -> Msg) -> String -> Html Msg
viewCompactField labelText inputType val toMsg width =
    div [ style "display" "flex", style "flex-direction" "column" ]
        [ label
            [ style "font-size" "0.7em"
            , style "color" "#888"
            , style "margin-bottom" "3px"
            ]
            [ text labelText ]
        , input
            [ type_ inputType
            , value val
            , onInput toMsg
            , style "width" width
            , style "padding" "8px"
            , style "background" "#1a1a2e"
            , style "border" "1px solid #333"
            , style "border-radius" "4px"
            , style "color" "#eee"
            , style "font-size" "0.9em"
            , style "box-sizing" "border-box"
            , if inputType == "number" then step "0.01" else style "" ""
            ]
            []
        ]

viewRecentEntries : List Entry -> Html Msg
viewRecentEntries entries =
    let
        recent = List.take 3 (List.reverse entries)
    in
    if List.isEmpty recent then
        text ""
    else
        div [ style "margin-bottom" "20px" ]
            [ h2
                [ style "font-weight" "300"
                , style "font-size" "1em"
                , style "margin-bottom" "10px"
                , style "color" "#888"
                ]
                [ text "Recent Entries" ]
            , div [] (List.map viewRecentEntry recent)
            ]

viewRecentEntry : Entry -> Html Msg
viewRecentEntry entry =
    div
        [ style "display" "flex"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "padding" "10px"
        , style "background" "#252542"
        , style "border-radius" "6px"
        , style "margin-bottom" "8px"
        , style "font-size" "0.85em"
        ]
        [ div [ style "display" "flex", style "gap" "15px", style "flex-wrap" "wrap", style "flex" "1" ]
            [ span [ style "color" "#888" ] [ text entry.date ]
            , span [] [ text ("Chk: $" ++ formatAmount entry.checking) ]
            , span [] [ text ("Crd: $" ++ formatAmount entry.creditAvailable) ]
            , if entry.hoursWorked > 0 then
                span [ style "color" "#4ade80" ]
                    [ text (formatAmount entry.hoursWorked ++ "h @ $" ++ formatAmount entry.payPerHour) ]
              else
                text ""
            , if entry.otherIncoming > 0 then
                span [ style "color" "#4ade80" ] [ text ("+$" ++ formatAmount entry.otherIncoming) ]
              else
                text ""
            , if entry.note /= "" then
                span [ style "color" "#888", style "font-style" "italic" ] [ text entry.note ]
              else
                text ""
            ]
        , button
            [ onClick (DeleteEntry entry.id)
            , style "background" "transparent"
            , style "border" "none"
            , style "color" "#ff6b6b"
            , style "font-size" "1.2em"
            , style "cursor" "pointer"
            , style "padding" "0 5px"
            ]
            [ text "X" ]
        ]

viewCalculated : List Entry -> Html Msg
viewCalculated _ =
    div
        [ style "background" "#252542"
        , style "padding" "15px"
        , style "border-radius" "12px"
        , style "margin-bottom" "20px"
        ]
        [ h2
            [ style "font-weight" "300"
            , style "font-size" "1em"
            , style "margin" "0 0 10px 0"
            , style "color" "#888"
            ]
            [ text "Calculated" ]
        ]


viewGraphPlaceholder : Html Msg
viewGraphPlaceholder =
    div
        [ style "background" "#252542"
        , style "padding" "40px"
        , style "border-radius" "12px"
        , style "text-align" "center"
        , style "color" "#888"
        , style "margin-bottom" "20px"
        ]
        [ text "[ TODO: Graph will go here ]" ]

viewMessageForMom : Html Msg
viewMessageForMom =
    div
        [ style "background" "linear-gradient(to right, #667eea, #764ba2)"
        , style "padding" "20px"
        , style "border-radius" "12px"
        , style "text-align" "center"
        , style "margin-top" "20px"
        ]
        [ p
            [ style "margin" "0"
            , style "font-size" "1.1em"
            ]
            [ text "Hi Mom! Logan wanted me to tell you:" ]
        , p
            [ style "margin" "10px 0 0 0"
            , style "font-size" "1.3em"
            , style "font-weight" "500"
            ]
            [ text "Your knee and ankle will get better and better!" ]
        ]

formatAmount : Float -> String
formatAmount amount =
    let
        intPart = floor amount
        decPart = round ((amount - toFloat intPart) * 100)
        decStr = if decPart < 10 then "0" ++ String.fromInt decPart else String.fromInt decPart
    in
    String.fromInt intPart ++ "." ++ decStr
