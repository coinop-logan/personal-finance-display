module Main exposing (main)

import Api.Types exposing (Entry, NewEntry, entryDecoder, newEntryEncoder)
import Browser
import Browser.Navigation as Nav
import Calculations exposing (dateToDays, daysToDateString, dayOfWeekName, incomingPayForEntry)
import Element exposing (..)
import Graph
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Http
import Json.Decode as Decode exposing (Decoder)
import Time
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
    , creditLimit : String
    , hoursWorkedHours : String
    , hoursWorkedMinutes : String
    , payPerHour : String
    , otherIncoming : String
    , personalDebt : String
    , note : String
    , payCashed : Bool
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
    , creditLimit = ""
    , hoursWorkedHours = ""
    , hoursWorkedMinutes = ""
    , payPerHour = ""
    , otherIncoming = ""
    , personalDebt = ""
    , note = ""
    , payCashed = False
    }


formFromLastEntry : Int -> Entry -> EntryForm
formFromLastEntry todayDays entry =
    { dateDays = todayDays
    , checking = String.fromFloat entry.checking
    , creditAvailable = String.fromFloat entry.creditAvailable
    , creditLimit = String.fromFloat entry.creditLimit
    , hoursWorkedHours = ""  -- Don't carry over hours, default to empty
    , hoursWorkedMinutes = ""
    , payPerHour = String.fromFloat entry.payPerHour
    , otherIncoming = String.fromFloat entry.otherIncoming
    , personalDebt = String.fromFloat entry.personalDebt
    , note = ""
    , payCashed = False  -- Don't carry over, default to unchecked
    }


formFromEntry : Entry -> EntryForm
formFromEntry entry =
    let
        -- Convert decimal hours back to hours:minutes
        totalMinutes = round (entry.hoursWorked * 60)
        hours = totalMinutes // 60
        minutes = remainderBy 60 totalMinutes
    in
    { dateDays = dateToDays entry.date
    , checking = String.fromFloat entry.checking
    , creditAvailable = String.fromFloat entry.creditAvailable
    , creditLimit = String.fromFloat entry.creditLimit
    , hoursWorkedHours = if hours > 0 || minutes > 0 then String.fromInt hours else ""
    , hoursWorkedMinutes = if hours > 0 || minutes > 0 then String.fromInt minutes else ""
    , payPerHour = String.fromFloat entry.payPerHour
    , otherIncoming = String.fromFloat entry.otherIncoming
    , personalDebt = String.fromFloat entry.personalDebt
    , note = entry.note
    , payCashed = entry.payCashed
    }


formFromEntries : Int -> List Entry -> EntryForm
formFromEntries todayDays entries =
    case List.reverse entries |> List.head of
        Just lastEntry ->
            formFromLastEntry todayDays lastEntry

        Nothing ->
            emptyForm todayDays


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
    | Tick Time.Posix
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | UpdateChecking String
    | UpdateCreditAvailable String
    | UpdateCreditLimit String
    | UpdateHoursWorkedHours String
    | UpdateHoursWorkedMinutes String
    | UpdatePayPerHour String
    | UpdateOtherIncoming String
    | UpdatePersonalDebt String
    | UpdateNote String
    | AdjustDate Int
    | TogglePayCashed Bool
    | SubmitEntry
    | SubmitResult (Result Http.Error ())
    | EditEntry Entry
    | DeleteEntry Int
    | DeleteResult (Result Http.Error ())

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

        Tick _ ->
            ( model, fetchData )

        UrlChanged url ->
            ( { model | page = urlToPage url }, Cmd.none )

        LinkClicked request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UpdateChecking val ->
            let f = model.form in
            ( { model | form = { f | checking = val } }, Cmd.none )

        UpdateCreditAvailable val ->
            let f = model.form in
            ( { model | form = { f | creditAvailable = val } }, Cmd.none )

        UpdateCreditLimit val ->
            let f = model.form in
            ( { model | form = { f | creditLimit = val } }, Cmd.none )

        UpdateHoursWorkedHours val ->
            let f = model.form in
            ( { model | form = { f | hoursWorkedHours = val } }, Cmd.none )

        UpdateHoursWorkedMinutes val ->
            let f = model.form in
            ( { model | form = { f | hoursWorkedMinutes = val } }, Cmd.none )

        UpdatePayPerHour val ->
            let f = model.form in
            ( { model | form = { f | payPerHour = val } }, Cmd.none )

        UpdateOtherIncoming val ->
            let f = model.form in
            ( { model | form = { f | otherIncoming = val } }, Cmd.none )

        UpdatePersonalDebt val ->
            let f = model.form in
            ( { model | form = { f | personalDebt = val } }, Cmd.none )

        UpdateNote val ->
            let f = model.form in
            ( { model | form = { f | note = val } }, Cmd.none )

        AdjustDate delta ->
            let f = model.form in
            ( { model | form = { f | dateDays = f.dateDays + delta } }, Cmd.none )

        TogglePayCashed val ->
            let f = model.form in
            ( { model | form = { f | payCashed = val } }, Cmd.none )

        SubmitEntry ->
            let
                f = model.form
                dateStr = daysToDateString f.dateDays

                -- Convert hours:minutes to decimal hours
                hours = String.toFloat f.hoursWorkedHours |> Maybe.withDefault 0
                minutes = String.toFloat f.hoursWorkedMinutes |> Maybe.withDefault 0
                totalHours = hours + (minutes / 60)

                maybeEntry =
                    Maybe.map2
                        (\checking creditAvailable ->
                            { date = dateStr
                            , checking = checking
                            , creditAvailable = creditAvailable
                            , creditLimit = String.toFloat f.creditLimit |> Maybe.withDefault 0
                            , hoursWorked = totalHours
                            , payPerHour = String.toFloat f.payPerHour |> Maybe.withDefault 0
                            , otherIncoming = String.toFloat f.otherIncoming |> Maybe.withDefault 0
                            , personalDebt = String.toFloat f.personalDebt |> Maybe.withDefault 0
                            , note = f.note
                            , payCashed = f.payCashed
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

        EditEntry entry ->
            ( { model | form = formFromEntry entry }, Cmd.none )

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


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
    case model.page of
        GraphPage ->
            Time.every 1000 Tick

        EntryPage ->
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


-- COLORS

colors =
    { background = rgb255 26 26 46
    , cardBg = rgb255 37 37 66
    , text = rgb255 238 238 238
    , textMuted = rgb255 136 136 136
    , accent = rgb255 79 172 254
    , accentEnd = rgb255 0 242 254
    , green = rgb255 74 222 128
    , red = rgb255 255 107 107
    , yellow = rgb255 251 191 36
    , border = rgb255 51 51 51
    }


-- VIEW

view : Model -> Browser.Document Msg
view model =
    let
        layoutAttrs =
            case model.page of
                GraphPage ->
                    [ Background.color colors.background
                    , Font.color colors.text
                    , Font.family [ Font.typeface "system-ui", Font.sansSerif ]
                    ]

                EntryPage ->
                    [ Background.color colors.background
                    , Font.color colors.text
                    , Font.family [ Font.typeface "system-ui", Font.sansSerif ]
                    , padding 20
                    ]
    in
    { title = "Finance Tracker"
    , body =
        [ layout layoutAttrs (viewBody model)
        ]
    }

viewBody : Model -> Element Msg
viewBody model =
    case model.page of
        GraphPage ->
            viewGraphPage model

        EntryPage ->
            viewEntryPage model

viewGraphPage : Model -> Element Msg
viewGraphPage model =
    if model.loading then
        el [] (text "Loading...")
    else
        Graph.viewGraph model.entries

viewEntryPage : Model -> Element Msg
viewEntryPage model =
    column [ spacing 20, width fill ]
        [ el [ Font.size 24, Font.light ] (text "Data Entry")
        , if model.loading then
            el [] (text "Loading...")
          else
            column [ spacing 20, width fill ]
                [ viewEntryForm model
                , viewRecentEntries model.entries
                ]
        , case model.error of
            Just err ->
                el [ Font.color colors.red ] (text err)
            Nothing ->
                none
        ]

viewEntryForm : Model -> Element Msg
viewEntryForm model =
    wrappedRow
        [ Background.color colors.cardBg
        , padding 15
        , Border.rounded 12
        , spacing 10
        ]
        [ viewDatePicker model.form.dateDays
        , viewCompactField "Checking" model.form.checking UpdateChecking 90
        , viewCompactField "Credit Avail" model.form.creditAvailable UpdateCreditAvailable 90
        , viewCompactField "Credit Limit" model.form.creditLimit UpdateCreditLimit 90
        , viewHoursMinutesField model.form.hoursWorkedHours model.form.hoursWorkedMinutes
        , viewCompactField "$/hr" model.form.payPerHour UpdatePayPerHour 70
        , viewCompactField "Other $" model.form.otherIncoming UpdateOtherIncoming 80
        , viewCompactField "Pers. Debt" model.form.personalDebt UpdatePersonalDebt 80
        , viewCompactField "Note" model.form.note UpdateNote 120
        , viewCheckbox "Pay Cashed" model.form.payCashed TogglePayCashed
        , Input.button
            [ Background.gradient { angle = pi / 2, steps = [ colors.accent, colors.accentEnd ] }
            , paddingXY 20 8
            , Border.rounded 6
            , Font.color colors.background
            , Font.size 20
            , Font.bold
            ]
            { onPress = Just SubmitEntry
            , label = text (if model.submitting then "..." else "+")
            }
        ]

viewDatePicker : Int -> Element Msg
viewDatePicker dateDays =
    let
        dateStr = daysToDateString dateDays
        weekday = dayOfWeekName dateDays
    in
    column [ spacing 3 ]
        [ el [ Font.size 11, Font.color colors.textMuted ] (text "Date")
        , row []
            [ column []
                [ Input.button
                    [ Background.color colors.background
                    , Border.width 1
                    , Border.color colors.border
                    , Border.roundEach { topLeft = 4, topRight = 0, bottomLeft = 0, bottomRight = 0 }
                    , paddingXY 8 2
                    , Font.size 11
                    ]
                    { onPress = Just (AdjustDate 1)
                    , label = text "▲"
                    }
                , Input.button
                    [ Background.color colors.background
                    , Border.widthEach { top = 0, right = 1, bottom = 1, left = 1 }
                    , Border.color colors.border
                    , Border.roundEach { topLeft = 0, topRight = 0, bottomLeft = 4, bottomRight = 0 }
                    , paddingXY 8 2
                    , Font.size 11
                    ]
                    { onPress = Just (AdjustDate -1)
                    , label = text "▼"
                    }
                ]
            , el
                [ Background.color colors.background
                , Border.width 1
                , Border.color colors.border
                , Border.roundEach { topLeft = 0, topRight = 4, bottomLeft = 0, bottomRight = 4 }
                , paddingXY 12 8
                , Font.size 14
                , width (px 120)
                ]
                ( row [ spacing 5 ]
                    [ el [ Font.bold, Font.color (rgb 1 1 1) ] (text weekday)
                    , text dateStr
                    ]
                )
            ]
        ]


viewCompactField : String -> String -> (String -> Msg) -> Int -> Element Msg
viewCompactField labelText val toMsg widthPx =
    column [ spacing 3 ]
        [ el [ Font.size 11, Font.color colors.textMuted ] (text labelText)
        , Input.text
            [ Background.color colors.background
            , Border.width 1
            , Border.color colors.border
            , Border.rounded 4
            , Font.size 14
            , width (px widthPx)
            , paddingXY 8 8
            ]
            { onChange = toMsg
            , text = val
            , placeholder = Nothing
            , label = Input.labelHidden labelText
            }
        ]


viewHoursMinutesField : String -> String -> Element Msg
viewHoursMinutesField hoursVal minutesVal =
    column [ spacing 3 ]
        [ el [ Font.size 11, Font.color colors.textMuted ] (text "Hours Today")
        , row []
            [ Input.text
                [ Background.color colors.background
                , Border.widthEach { top = 1, right = 0, bottom = 1, left = 1 }
                , Border.color colors.border
                , Border.roundEach { topLeft = 4, topRight = 0, bottomLeft = 4, bottomRight = 0 }
                , Font.size 14
                , width (px 35)
                , paddingXY 4 8
                ]
                { onChange = UpdateHoursWorkedHours
                , text = hoursVal
                , placeholder = Nothing
                , label = Input.labelHidden "Hours"
                }
            , el
                [ Background.color colors.background
                , Border.widthEach { top = 1, right = 0, bottom = 1, left = 0 }
                , Border.color colors.border
                , paddingXY 2 8
                , Font.color colors.textMuted
                , Font.size 14
                ]
                (text ":")
            , Input.text
                [ Background.color colors.background
                , Border.widthEach { top = 1, right = 1, bottom = 1, left = 0 }
                , Border.color colors.border
                , Border.roundEach { topLeft = 0, topRight = 4, bottomLeft = 0, bottomRight = 4 }
                , Font.size 14
                , width (px 35)
                , paddingXY 4 8
                ]
                { onChange = UpdateHoursWorkedMinutes
                , text = minutesVal
                , placeholder = Nothing
                , label = Input.labelHidden "Minutes"
                }
            ]
        ]


viewCheckbox : String -> Bool -> (Bool -> Msg) -> Element Msg
viewCheckbox labelText isChecked toMsg =
    column [ spacing 3, centerX ]
        [ el [ Font.size 11, Font.color colors.textMuted, centerX ] (text labelText)
        , Input.checkbox []
            { onChange = toMsg
            , icon = Input.defaultCheckbox
            , checked = isChecked
            , label = Input.labelHidden labelText
            }
        ]

viewRecentEntries : List Entry -> Element Msg
viewRecentEntries entries =
    let
        recent = List.take 25 (List.reverse entries)
    in
    if List.isEmpty recent then
        none
    else
        column [ spacing 10, width fill ]
            [ el [ Font.size 16, Font.light, Font.color colors.textMuted ] (text "Recent Entries")
            , column [ spacing 8, width fill ] (List.map (viewRecentEntry entries) recent)
            ]

viewRecentEntry : List Entry -> Entry -> Element Msg
viewRecentEntry allEntries entry =
    let
        incomingPay = incomingPayForEntry entry allEntries
        entryDays = dateToDays entry.date
        weekday = dayOfWeekName entryDays
    in
    column
        [ Background.color colors.cardBg
        , Border.rounded 6
        , padding 10
        , spacing 5
        , width fill
        , Font.size 13
        ]
        [ row [ width fill, spacing 15 ]
            [ wrappedRow [ spacing 15, width fill ]
                [ row [ spacing 5 ]
                    [ el [ Font.bold, Font.color (rgb 1 1 1) ] (text weekday)
                    , el [ Font.color colors.textMuted ] (text entry.date)
                    ]
                , text ("Chk: $" ++ formatAmount entry.checking)
                , text ("Crd: $" ++ formatAmount entry.creditAvailable)
                , if entry.hoursWorked > 0 then
                    el [ Font.color colors.green ]
                        (text (formatAmount entry.hoursWorked ++ "h @ $" ++ formatAmount entry.payPerHour))
                  else
                    none
                , if entry.otherIncoming > 0 then
                    el [ Font.color colors.green ] (text ("+$" ++ formatAmount entry.otherIncoming))
                  else
                    none
                , if entry.payCashed then
                    el [ Font.color colors.yellow ] (text "[Cashed]")
                  else
                    none
                , if entry.note /= "" then
                    el [ Font.color colors.textMuted, Font.italic ] (text entry.note)
                  else
                    none
                ]
            , row [ spacing 5 ]
                [ Input.button [ Font.color colors.accent, Font.size 14 ]
                    { onPress = Just (EditEntry entry)
                    , label = text "Edit"
                    }
                , Input.button [ Font.color colors.red, Font.size 18 ]
                    { onPress = Just (DeleteEntry entry.id)
                    , label = text "X"
                    }
                ]
            ]
        , row
            [ Border.widthEach { top = 1, right = 0, bottom = 0, left = 0 }
            , Border.color colors.border
            , paddingEach { top = 5, right = 0, bottom = 0, left = 0 }
            , width fill
            , Font.size 12
            ]
            [ el [ Font.color colors.textMuted ] (text "Incoming: ")
            , el [ Font.color colors.green, Font.medium ] (text ("$" ++ formatAmount incomingPay))
            ]
        ]


formatAmount : Float -> String
formatAmount amount =
    let
        intPart = floor amount
        decPart = round ((amount - toFloat intPart) * 100)
        decStr = if decPart < 10 then "0" ++ String.fromInt decPart else String.fromInt decPart
    in
    String.fromInt intPart ++ "." ++ decStr
