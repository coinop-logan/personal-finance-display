module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, div, text, h1, h2, p, input, button, label, span)
import Html.Attributes exposing (style, type_, value, placeholder, step, id)
import Html.Events exposing (onInput, onClick)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
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

type alias Entry =
    { id : Int
    , date : String
    , checking : Float
    , creditAvailable : Float
    , hoursWorked : Float
    , payPerHour : Float
    , otherIncoming : Float
    , note : String
    }

type alias EntryForm =
    { date : String
    , checking : String
    , creditAvailable : String
    , hoursWorked : String
    , payPerHour : String
    , otherIncoming : String
    , note : String
    }

type alias Model =
    { entries : List Entry
    , error : Maybe String
    , loading : Bool
    , form : EntryForm
    , submitting : Bool
    , key : Nav.Key
    , today : String
    }

emptyForm : String -> String -> EntryForm
emptyForm today lastPayPerHour =
    { date = today
    , checking = ""
    , creditAvailable = ""
    , hoursWorked = ""
    , payPerHour = lastPayPerHour
    , otherIncoming = ""
    , note = ""
    }

init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { entries = []
      , error = Nothing
      , loading = True
      , form = emptyForm flags.today ""
      , submitting = False
      , key = key
      , today = flags.today
      }
    , fetchData
    )


-- UPDATE

type Msg
    = GotData (Result Http.Error (List Entry))
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | UpdateForm FormField String
    | SubmitEntry
    | SubmitResult (Result Http.Error ())
    | DeleteEntry Int
    | DeleteResult (Result Http.Error ())

type FormField
    = Date
    | Checking
    | CreditAvailable
    | HoursWorked
    | PayPerHour
    | OtherIncoming
    | Note

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotData result ->
            case result of
                Ok entries ->
                    let
                        lastPayPerHour =
                            entries
                                |> List.reverse
                                |> List.head
                                |> Maybe.map (.payPerHour >> String.fromFloat)
                                |> Maybe.withDefault ""

                        updatedForm =
                            if model.form.payPerHour == "" then
                                { date = model.form.date
                                , checking = model.form.checking
                                , creditAvailable = model.form.creditAvailable
                                , hoursWorked = model.form.hoursWorked
                                , payPerHour = lastPayPerHour
                                , otherIncoming = model.form.otherIncoming
                                , note = model.form.note
                                }
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

        UrlChanged _ ->
            ( model, Cmd.none )

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
                        Date -> { f | date = val }
                        Checking -> { f | checking = val }
                        CreditAvailable -> { f | creditAvailable = val }
                        HoursWorked -> { f | hoursWorked = val }
                        PayPerHour -> { f | payPerHour = val }
                        OtherIncoming -> { f | otherIncoming = val }
                        Note -> { f | note = val }
            in
            ( { model | form = newForm }, Cmd.none )

        SubmitEntry ->
            let
                f = model.form
                checking = String.toFloat f.checking |> Maybe.withDefault 0
                creditAvailable = String.toFloat f.creditAvailable |> Maybe.withDefault 0
                hoursWorked = String.toFloat f.hoursWorked |> Maybe.withDefault 0
                payPerHour = String.toFloat f.payPerHour |> Maybe.withDefault 0
                otherIncoming = String.toFloat f.otherIncoming |> Maybe.withDefault 0
            in
            ( { model | submitting = True }
            , submitEntry f.date checking creditAvailable hoursWorked payPerHour otherIncoming f.note
            )

        SubmitResult result ->
            case result of
                Ok _ ->
                    let
                        lastPayPerHour = model.form.payPerHour
                    in
                    ( { model
                        | submitting = False
                        , form = emptyForm model.today lastPayPerHour
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

submitEntry : String -> Float -> Float -> Float -> Float -> Float -> String -> Cmd Msg
submitEntry date checking creditAvailable hoursWorked payPerHour otherIncoming note =
    Http.post
        { url = "/api/entry"
        , body = Http.jsonBody (encodeEntry date checking creditAvailable hoursWorked payPerHour otherIncoming note)
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

encodeEntry : String -> Float -> Float -> Float -> Float -> Float -> String -> Encode.Value
encodeEntry date checking creditAvailable hoursWorked payPerHour otherIncoming note =
    Encode.object
        [ ( "date", Encode.string date )
        , ( "checking", Encode.float checking )
        , ( "creditAvailable", Encode.float creditAvailable )
        , ( "hoursWorked", Encode.float hoursWorked )
        , ( "payPerHour", Encode.float payPerHour )
        , ( "otherIncoming", Encode.float otherIncoming )
        , ( "note", Encode.string note )
        ]

dataDecoder : Decoder (List Entry)
dataDecoder =
    Decode.list entryDecoder

entryDecoder : Decoder Entry
entryDecoder =
    Decode.map8 Entry
        (Decode.field "id" Decode.int)
        (Decode.field "date" Decode.string)
        (Decode.field "checking" Decode.float)
        (Decode.field "creditAvailable" Decode.float)
        (Decode.field "hoursWorked" Decode.float)
        (Decode.field "payPerHour" Decode.float)
        (Decode.field "otherIncoming" Decode.float)
        (Decode.field "note" Decode.string)


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
        [ h1
            [ style "margin" "0 0 20px 0"
            , style "font-weight" "300"
            , style "font-size" "1.5em"
            ]
            [ text "Finance Tracker" ]
        , if model.loading then
            p [] [ text "Loading..." ]
          else
            div []
                [ viewEntryForm model
                , viewRecentEntries model.entries
                , viewGraphPlaceholder
                , viewMessageForMom
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
            [ viewCompactField "Date" "date" model.form.date (UpdateForm Date) "100px"
            , viewCompactField "Checking" "number" model.form.checking (UpdateForm Checking) "90px"
            , viewCompactField "Credit Avail" "number" model.form.creditAvailable (UpdateForm CreditAvailable) "90px"
            , viewCompactField "Hours" "number" model.form.hoursWorked (UpdateForm HoursWorked) "70px"
            , viewCompactField "$/hr" "number" model.form.payPerHour (UpdateForm PayPerHour) "70px"
            , viewCompactField "Other $" "number" model.form.otherIncoming (UpdateForm OtherIncoming) "80px"
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
