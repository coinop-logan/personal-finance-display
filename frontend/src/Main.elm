module Main exposing (main)

import Api.Types exposing (BalanceSnapshot, WorkLog, Job, FinanceData, NewBalanceSnapshot, NewWorkLog, Weather, financeDataDecoder, newBalanceSnapshotEncoder, newWorkLogEncoder, weatherDecoder)
import Browser
import Browser.Navigation as Nav
import Calculations exposing (dateToDays, daysToDateString, dayOfWeekName, calculateIncomingPay)
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


type alias Flags =
    { today : String }

type NoteColor
    = NoColor
    | Green
    | Blue
    | Red
    | Yellow

noteColorToString : NoteColor -> String
noteColorToString color =
    case color of
        NoColor -> ""
        Green -> "green"
        Blue -> "blue"
        Red -> "red"
        Yellow -> "yellow"

noteColorFromString : String -> NoteColor
noteColorFromString str =
    case str of
        "green" -> Green
        "blue" -> Blue
        "red" -> Red
        "yellow" -> Yellow
        _ -> NoColor

encodeNoteWithColor : NoteColor -> String -> String
encodeNoteWithColor color noteText =
    case color of
        NoColor -> noteText
        _ -> noteColorToString color ++ ":" ++ noteText

decodeNoteWithColor : String -> (NoteColor, String)
decodeNoteWithColor encoded =
    case String.split ":" encoded of
        colorStr :: rest ->
            let
                color = noteColorFromString colorStr
            in
            case color of
                NoColor -> (NoColor, encoded)
                _ -> (color, String.join ":" rest)
        _ -> (NoColor, encoded)


type alias BalanceForm =
    { dateDays : Int
    , checking : String
    , creditAvailable : String
    , creditLimit : String
    , personalDebt : String
    , note : String
    , noteColor : NoteColor
    }

type alias WorkLogForm =
    { dateDays : Int
    , jobId : String
    , hoursHours : String
    , hoursMinutes : String
    , payRate : String
    , taxRate : String
    , payCashed : Bool
    }

type Page
    = GraphPage
    | EntryPage

type alias Model =
    { jobs : List Job
    , workLogs : List WorkLog
    , balanceSnapshots : List BalanceSnapshot
    , error : Maybe String
    , loading : Bool
    , page : Page
    , balanceForm : BalanceForm
    , workLogForm : WorkLogForm
    , submitting : Bool
    , key : Nav.Key
    , todayDays : Int
    , currentTime : Time.Posix
    , weather : Maybe Weather
    }

emptyBalanceForm : Int -> BalanceForm
emptyBalanceForm todayDays =
    { dateDays = todayDays
    , checking = ""
    , creditAvailable = ""
    , creditLimit = ""
    , personalDebt = ""
    , note = ""
    , noteColor = NoColor
    }

emptyWorkLogForm : Int -> String -> WorkLogForm
emptyWorkLogForm todayDays defaultJobId =
    { dateDays = todayDays
    , jobId = defaultJobId
    , hoursHours = ""
    , hoursMinutes = ""
    , payRate = ""
    , taxRate = "0.25"
    , payCashed = False
    }


balanceFormFromSnapshot : BalanceSnapshot -> BalanceForm
balanceFormFromSnapshot snapshot =
    let
        (noteColor, noteText) = decodeNoteWithColor snapshot.note
    in
    { dateDays = dateToDays snapshot.date
    , checking = String.fromFloat snapshot.checking
    , creditAvailable = String.fromFloat snapshot.creditAvailable
    , creditLimit = String.fromFloat snapshot.creditLimit
    , personalDebt = String.fromFloat snapshot.personalDebt
    , note = noteText
    , noteColor = noteColor
    }


balanceFormFromLastSnapshot : Int -> List BalanceSnapshot -> BalanceForm
balanceFormFromLastSnapshot todayDays snapshots =
    case List.reverse snapshots |> List.head of
        Just snapshot ->
            { dateDays = todayDays
            , checking = String.fromFloat snapshot.checking
            , creditAvailable = String.fromFloat snapshot.creditAvailable
            , creditLimit = String.fromFloat snapshot.creditLimit
            , personalDebt = String.fromFloat snapshot.personalDebt
            , note = ""
            , noteColor = NoColor
            }
        Nothing ->
            emptyBalanceForm todayDays


workLogFormFromLastLog : Int -> String -> List WorkLog -> WorkLogForm
workLogFormFromLastLog todayDays jobId workLogs =
    let
        logsForJob = List.filter (\w -> w.jobId == jobId) workLogs
    in
    case List.reverse logsForJob |> List.head of
        Just log ->
            { dateDays = todayDays
            , jobId = jobId
            , hoursHours = ""
            , hoursMinutes = ""
            , payRate = String.fromFloat log.payRate
            , taxRate = String.fromFloat log.taxRate
            , payCashed = False
            }
        Nothing ->
            emptyWorkLogForm todayDays jobId


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
    ( { jobs = []
      , workLogs = []
      , balanceSnapshots = []
      , error = Nothing
      , loading = True
      , page = urlToPage url
      , balanceForm = emptyBalanceForm todayDays
      , workLogForm = emptyWorkLogForm todayDays "alborn"
      , submitting = False
      , key = key
      , todayDays = todayDays
      , currentTime = Time.millisToPosix 0
      , weather = Nothing
      }
    , Cmd.batch [ fetchData, fetchWeather ]
    )


type Msg
    = GotData (Result Http.Error FinanceData)
    | GotWeather (Result Http.Error Weather)
    | Tick Time.Posix
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
    -- Balance form
    | UpdateBalanceChecking String
    | UpdateBalanceCreditAvailable String
    | UpdateBalanceCreditLimit String
    | UpdateBalancePersonalDebt String
    | UpdateBalanceNote String
    | UpdateBalanceNoteColor NoteColor
    | AdjustBalanceDate Int
    | SubmitBalance
    | SubmitBalanceResult (Result Http.Error ())
    | EditSnapshot BalanceSnapshot
    | DeleteSnapshot Int
    | DeleteSnapshotResult (Result Http.Error ())
    -- Work log form
    | UpdateWorkLogJobId String
    | UpdateWorkLogHoursHours String
    | UpdateWorkLogHoursMinutes String
    | UpdateWorkLogPayRate String
    | UpdateWorkLogTaxRate String
    | UpdateWorkLogPayCashed Bool
    | AdjustWorkLogDate Int
    | SubmitWorkLog
    | SubmitWorkLogResult (Result Http.Error ())
    | DeleteWorkLog Int
    | DeleteWorkLogResult (Result Http.Error ())

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotData result ->
            case result of
                Ok data ->
                    let
                        updatedBalanceForm =
                            if model.balanceForm.checking == "" then
                                balanceFormFromLastSnapshot model.todayDays data.balanceSnapshots
                            else
                                model.balanceForm

                        defaultJobId =
                            data.jobs |> List.head |> Maybe.map .id |> Maybe.withDefault "alborn"

                        updatedWorkLogForm =
                            if model.workLogForm.payRate == "" then
                                workLogFormFromLastLog model.todayDays defaultJobId data.workLogs
                            else
                                model.workLogForm
                    in
                    ( { model
                        | jobs = data.jobs
                        , workLogs = data.workLogs
                        , balanceSnapshots = data.balanceSnapshots
                        , loading = False
                        , error = Nothing
                        , balanceForm = updatedBalanceForm
                        , workLogForm = updatedWorkLogForm
                      }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | loading = False, error = Just (httpErrorToString err) }
                    , Cmd.none
                    )

        GotWeather result ->
            case result of
                Ok weather ->
                    ( { model | weather = Just weather }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Tick time ->
            ( { model | currentTime = time }, fetchData )

        UrlChanged url ->
            ( { model | page = urlToPage url }, Cmd.none )

        LinkClicked request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        -- Balance form updates
        UpdateBalanceChecking val ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | checking = val } }, Cmd.none )

        UpdateBalanceCreditAvailable val ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | creditAvailable = val } }, Cmd.none )

        UpdateBalanceCreditLimit val ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | creditLimit = val } }, Cmd.none )

        UpdateBalancePersonalDebt val ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | personalDebt = val } }, Cmd.none )

        UpdateBalanceNote val ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | note = val } }, Cmd.none )

        UpdateBalanceNoteColor color ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | noteColor = color } }, Cmd.none )

        AdjustBalanceDate delta ->
            let f = model.balanceForm in
            ( { model | balanceForm = { f | dateDays = f.dateDays + delta } }, Cmd.none )

        SubmitBalance ->
            let
                f = model.balanceForm
                dateStr = daysToDateString f.dateDays
                encodedNote = encodeNoteWithColor f.noteColor f.note

                maybeSnapshot =
                    Maybe.map2
                        (\checking creditAvailable ->
                            { date = dateStr
                            , checking = checking
                            , creditAvailable = creditAvailable
                            , creditLimit = String.toFloat f.creditLimit |> Maybe.withDefault 0
                            , personalDebt = String.toFloat f.personalDebt |> Maybe.withDefault 0
                            , note = encodedNote
                            }
                        )
                        (String.toFloat f.checking)
                        (String.toFloat f.creditAvailable)
            in
            case maybeSnapshot of
                Just newSnapshot ->
                    ( { model | submitting = True, error = Nothing }
                    , submitBalanceSnapshot newSnapshot
                    )

                Nothing ->
                    ( { model | error = Just "Checking and Credit Available are required" }
                    , Cmd.none
                    )

        SubmitBalanceResult result ->
            case result of
                Ok _ ->
                    ( { model
                        | submitting = False
                        , balanceForm = emptyBalanceForm model.todayDays
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

        EditSnapshot snapshot ->
            ( { model | balanceForm = balanceFormFromSnapshot snapshot }, Cmd.none )

        DeleteSnapshot snapshotId ->
            ( model, deleteBalanceSnapshot snapshotId )

        DeleteSnapshotResult result ->
            case result of
                Ok _ ->
                    ( model, fetchData )

                Err err ->
                    ( { model | error = Just (httpErrorToString err) }, Cmd.none )

        -- Work log form updates
        UpdateWorkLogJobId val ->
            let
                f = model.workLogForm
                -- When job changes, update pay/tax from most recent log for that job
                newForm = workLogFormFromLastLog model.todayDays val model.workLogs
            in
            ( { model | workLogForm = { newForm | dateDays = f.dateDays, hoursHours = f.hoursHours, hoursMinutes = f.hoursMinutes } }, Cmd.none )

        UpdateWorkLogHoursHours val ->
            let f = model.workLogForm in
            ( { model | workLogForm = { f | hoursHours = val } }, Cmd.none )

        UpdateWorkLogHoursMinutes val ->
            let f = model.workLogForm in
            ( { model | workLogForm = { f | hoursMinutes = val } }, Cmd.none )

        UpdateWorkLogPayRate val ->
            let f = model.workLogForm in
            ( { model | workLogForm = { f | payRate = val } }, Cmd.none )

        UpdateWorkLogTaxRate val ->
            let f = model.workLogForm in
            ( { model | workLogForm = { f | taxRate = val } }, Cmd.none )

        UpdateWorkLogPayCashed val ->
            let f = model.workLogForm in
            ( { model | workLogForm = { f | payCashed = val } }, Cmd.none )

        AdjustWorkLogDate delta ->
            let f = model.workLogForm in
            ( { model | workLogForm = { f | dateDays = f.dateDays + delta } }, Cmd.none )

        SubmitWorkLog ->
            let
                f = model.workLogForm
                dateStr = daysToDateString f.dateDays

                hours = String.toFloat f.hoursHours |> Maybe.withDefault 0
                minutes = String.toFloat f.hoursMinutes |> Maybe.withDefault 0
                totalHours = hours + (minutes / 60)

                maybeWorkLog =
                    Maybe.map2
                        (\payRate taxRate ->
                            { date = dateStr
                            , jobId = f.jobId
                            , hours = totalHours
                            , payRate = payRate
                            , taxRate = taxRate
                            , payCashed = f.payCashed
                            }
                        )
                        (String.toFloat f.payRate)
                        (String.toFloat f.taxRate)
            in
            case maybeWorkLog of
                Just newWorkLog ->
                    if totalHours > 0 then
                        ( { model | submitting = True, error = Nothing }
                        , submitWorkLog newWorkLog
                        )
                    else
                        ( { model | error = Just "Hours must be greater than 0" }
                        , Cmd.none
                        )

                Nothing ->
                    ( { model | error = Just "Pay rate and tax rate are required" }
                    , Cmd.none
                    )

        SubmitWorkLogResult result ->
            case result of
                Ok _ ->
                    let
                        f = model.workLogForm
                    in
                    ( { model
                        | submitting = False
                        , workLogForm = { f | hoursHours = "", hoursMinutes = "", payCashed = False }
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

        DeleteWorkLog workLogId ->
            ( model, deleteWorkLog workLogId )

        DeleteWorkLogResult result ->
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


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.page of
        GraphPage ->
            Time.every 1000 Tick

        EntryPage ->
            Sub.none


fetchData : Cmd Msg
fetchData =
    Http.get
        { url = "/api/data"
        , expect = Http.expectJson GotData financeDataDecoder
        }

fetchWeather : Cmd Msg
fetchWeather =
    Http.get
        { url = "/api/weather"
        , expect = Http.expectJson GotWeather weatherDecoder
        }

submitBalanceSnapshot : NewBalanceSnapshot -> Cmd Msg
submitBalanceSnapshot snapshot =
    Http.post
        { url = "/api/balance"
        , body = Http.jsonBody (newBalanceSnapshotEncoder snapshot)
        , expect = Http.expectWhatever SubmitBalanceResult
        }

deleteBalanceSnapshot : Int -> Cmd Msg
deleteBalanceSnapshot snapshotId =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/balance/" ++ String.fromInt snapshotId
        , body = Http.emptyBody
        , expect = Http.expectWhatever DeleteSnapshotResult
        , timeout = Nothing
        , tracker = Nothing
        }

submitWorkLog : NewWorkLog -> Cmd Msg
submitWorkLog workLog =
    Http.post
        { url = "/api/worklog"
        , body = Http.jsonBody (newWorkLogEncoder workLog)
        , expect = Http.expectWhatever SubmitWorkLogResult
        }

deleteWorkLog : Int -> Cmd Msg
deleteWorkLog workLogId =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/worklog/" ++ String.fromInt workLogId
        , body = Http.emptyBody
        , expect = Http.expectWhatever DeleteWorkLogResult
        , timeout = Nothing
        , tracker = Nothing
        }


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
        Graph.viewGraph model.balanceSnapshots model.workLogs model.currentTime model.weather

viewEntryPage : Model -> Element Msg
viewEntryPage model =
    column [ spacing 20, width fill ]
        [ el [ Font.size 24, Font.light ] (text "Data Entry")
        , if model.loading then
            el [] (text "Loading...")
          else
            column [ spacing 20, width fill ]
                [ Graph.viewMiniGraph model.balanceSnapshots model.workLogs
                , viewBalanceForm model
                , viewWorkLogForm model
                , viewRecentData model
                ]
        , case model.error of
            Just err ->
                el [ Font.color colors.red ] (text err)
            Nothing ->
                none
        ]

viewBalanceForm : Model -> Element Msg
viewBalanceForm model =
    column [ spacing 5 ]
        [ el [ Font.size 14, Font.color colors.textMuted ] (text "Balance Snapshot")
        , wrappedRow
            [ Background.color colors.cardBg
            , padding 15
            , Border.rounded 12
            , spacing 10
            ]
            [ viewDatePicker model.balanceForm.dateDays AdjustBalanceDate
            , viewCompactField "Checking" model.balanceForm.checking UpdateBalanceChecking 90
            , viewCompactField "Credit Avail" model.balanceForm.creditAvailable UpdateBalanceCreditAvailable 90
            , viewCompactField "Credit Limit" model.balanceForm.creditLimit UpdateBalanceCreditLimit 90
            , viewCompactField "Pers. Debt" model.balanceForm.personalDebt UpdateBalancePersonalDebt 80
            , viewNoteWithColor model.balanceForm.note model.balanceForm.noteColor
            , Input.button
                [ Background.gradient { angle = pi / 2, steps = [ colors.accent, colors.accentEnd ] }
                , paddingXY 20 8
                , Border.rounded 6
                , Font.color colors.background
                , Font.size 20
                , Font.bold
                ]
                { onPress = Just SubmitBalance
                , label = text (if model.submitting then "..." else "+")
                }
            ]
        ]

viewWorkLogForm : Model -> Element Msg
viewWorkLogForm model =
    column [ spacing 5 ]
        [ el [ Font.size 14, Font.color colors.textMuted ] (text "Work Log")
        , wrappedRow
            [ Background.color colors.cardBg
            , padding 15
            , Border.rounded 12
            , spacing 10
            ]
            [ viewDatePicker model.workLogForm.dateDays AdjustWorkLogDate
            , viewJobPicker model.jobs model.workLogForm.jobId
            , viewHoursMinutesField model.workLogForm.hoursHours model.workLogForm.hoursMinutes
            , viewCompactField "$/hr" model.workLogForm.payRate UpdateWorkLogPayRate 70
            , viewCompactField "Tax %" model.workLogForm.taxRate UpdateWorkLogTaxRate 60
            , viewPayCashedCheckbox model.workLogForm.payCashed
            , Input.button
                [ Background.gradient { angle = pi / 2, steps = [ colors.green, rgb255 34 197 94 ] }
                , paddingXY 20 8
                , Border.rounded 6
                , Font.color colors.background
                , Font.size 20
                , Font.bold
                ]
                { onPress = Just SubmitWorkLog
                , label = text (if model.submitting then "..." else "+")
                }
            ]
        ]

viewJobPicker : List Job -> String -> Element Msg
viewJobPicker jobs selectedJobId =
    column [ spacing 3 ]
        [ el [ Font.size 11, Font.color colors.textMuted ] (text "Job")
        , Input.radioRow
            [ spacing 8
            , padding 8
            , Background.color colors.background
            , Border.rounded 4
            , Border.width 1
            , Border.color colors.border
            ]
            { onChange = UpdateWorkLogJobId
            , selected = Just selectedJobId
            , label = Input.labelHidden "Job"
            , options = List.map (\job -> Input.option job.id (text job.name)) jobs
            }
        ]

viewPayCashedCheckbox : Bool -> Element Msg
viewPayCashedCheckbox isChecked =
    column [ spacing 3 ]
        [ el [ Font.size 11, Font.color colors.textMuted ] (text "Paid")
        , Input.checkbox
            [ padding 8
            , Background.color colors.background
            , Border.rounded 4
            , Border.width 1
            , Border.color colors.border
            ]
            { onChange = UpdateWorkLogPayCashed
            , checked = isChecked
            , icon = Input.defaultCheckbox
            , label = Input.labelRight [ Font.size 12 ] (text "$")
            }
        ]

viewDatePicker : Int -> (Int -> Msg) -> Element Msg
viewDatePicker dateDays adjustMsg =
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
                    { onPress = Just (adjustMsg 1)
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
                    { onPress = Just (adjustMsg -1)
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


viewNoteWithColor : String -> NoteColor -> Element Msg
viewNoteWithColor noteVal noteColor =
    column [ spacing 3 ]
        [ el [ Font.size 11, Font.color colors.textMuted ] (text "Note")
        , row [ spacing 5 ]
            [ Input.text
                [ Background.color colors.background
                , Border.width 1
                , Border.color colors.border
                , Border.rounded 4
                , Font.size 14
                , width (px 90)
                , paddingXY 8 8
                ]
                { onChange = UpdateBalanceNote
                , text = noteVal
                , placeholder = Nothing
                , label = Input.labelHidden "Note"
                }
            , Input.radioRow
                [ spacing 4 ]
                { onChange = UpdateBalanceNoteColor
                , selected = Just noteColor
                , label = Input.labelHidden "Color"
                , options =
                    [ Input.option NoColor (colorDot colors.textMuted "—")
                    , Input.option Green (colorDot (rgb255 74 222 128) "")
                    , Input.option Blue (colorDot (rgb255 96 165 250) "")
                    , Input.option Red (colorDot (rgb255 248 113 113) "")
                    , Input.option Yellow (colorDot (rgb255 251 191 36) "")
                    ]
                }
            ]
        ]

colorDot : Color -> String -> Element msg
colorDot color label =
    el
        [ Background.color color
        , width (px 16)
        , height (px 16)
        , Border.rounded 8
        , Border.width 1
        , Border.color colors.border
        ]
        (if label == "" then none else el [ centerX, centerY, Font.size 10 ] (text label))


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
        [ el [ Font.size 11, Font.color colors.textMuted ] (text "Hours")
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
                { onChange = UpdateWorkLogHoursHours
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
                { onChange = UpdateWorkLogHoursMinutes
                , text = minutesVal
                , placeholder = Nothing
                , label = Input.labelHidden "Minutes"
                }
            ]
        ]


viewRecentData : Model -> Element Msg
viewRecentData model =
    column [ spacing 20, width fill ]
        [ viewRecentSnapshots model.balanceSnapshots model.workLogs
        , viewRecentWorkLogs model.workLogs model.jobs
        ]

viewRecentSnapshots : List BalanceSnapshot -> List WorkLog -> Element Msg
viewRecentSnapshots snapshots workLogs =
    let
        recent = List.take 10 (List.reverse snapshots)
    in
    if List.isEmpty recent then
        none
    else
        column [ spacing 10, width fill ]
            [ el [ Font.size 16, Font.light, Font.color colors.textMuted ] (text "Recent Balance Snapshots")
            , column [ spacing 8, width fill ] (List.map (viewRecentSnapshot workLogs) recent)
            ]

viewRecentSnapshot : List WorkLog -> BalanceSnapshot -> Element Msg
viewRecentSnapshot workLogs snapshot =
    let
        snapshotDays = dateToDays snapshot.date
        weekday = dayOfWeekName snapshotDays
        incomingPay = calculateIncomingPay snapshotDays workLogs
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
                    , el [ Font.color colors.textMuted ] (text snapshot.date)
                    ]
                , text ("Chk: $" ++ formatAmount snapshot.checking)
                , text ("Crd: $" ++ formatAmount snapshot.creditAvailable)
                , if snapshot.note /= "" then
                    el [ Font.color colors.textMuted, Font.italic ] (text snapshot.note)
                  else
                    none
                ]
            , row [ spacing 5 ]
                [ Input.button [ Font.color colors.accent, Font.size 14 ]
                    { onPress = Just (EditSnapshot snapshot)
                    , label = text "Edit"
                    }
                , Input.button [ Font.color colors.red, Font.size 18 ]
                    { onPress = Just (DeleteSnapshot snapshot.id)
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

viewRecentWorkLogs : List WorkLog -> List Job -> Element Msg
viewRecentWorkLogs workLogs jobs =
    let
        recent = List.take 15 (List.reverse workLogs)
        getJobName jobId =
            jobs
                |> List.filter (\j -> j.id == jobId)
                |> List.head
                |> Maybe.map .name
                |> Maybe.withDefault jobId
    in
    if List.isEmpty recent then
        none
    else
        column [ spacing 10, width fill ]
            [ el [ Font.size 16, Font.light, Font.color colors.textMuted ] (text "Recent Work Logs")
            , column [ spacing 6, width fill ] (List.map (viewRecentWorkLog getJobName) recent)
            ]

viewRecentWorkLog : (String -> String) -> WorkLog -> Element Msg
viewRecentWorkLog getJobName workLog =
    let
        logDays = dateToDays workLog.date
        weekday = dayOfWeekName logDays
    in
    row
        [ Background.color colors.cardBg
        , Border.rounded 6
        , padding 10
        , width fill
        , Font.size 13
        , spacing 15
        ]
        [ row [ spacing 5 ]
            [ el [ Font.bold, Font.color (rgb 1 1 1) ] (text weekday)
            , el [ Font.color colors.textMuted ] (text workLog.date)
            ]
        , el [ Font.color colors.accent ] (text (getJobName workLog.jobId))
        , el [ Font.color colors.green ]
            (text (formatAmount workLog.hours ++ "h @ $" ++ formatAmount workLog.payRate))
        , el [ Font.color colors.textMuted ]
            (text ("Tax: " ++ String.fromInt (round (workLog.taxRate * 100)) ++ "%"))
        , if workLog.payCashed then
            el [ Font.color colors.yellow, Font.bold ] (text "$")
          else
            none
        , Input.button [ Font.color colors.red, Font.size 18, alignRight ]
            { onPress = Just (DeleteWorkLog workLog.id)
            , label = text "X"
            }
        ]


formatAmount : Float -> String
formatAmount amount =
    let
        intPart = floor amount
        decPart = round ((amount - toFloat intPart) * 100)
        decStr = if decPart < 10 then "0" ++ String.fromInt decPart else String.fromInt decPart
    in
    String.fromInt intPart ++ "." ++ decStr
