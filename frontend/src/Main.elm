module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, div, text, h1, h2, p, input, button, label, form, a)
import Html.Attributes exposing (style, type_, value, placeholder, href, step)
import Html.Events exposing (onInput, onClick, onSubmit)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Time
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>))


-- MAIN

main : Program () Model Msg
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

type alias DayEntry =
    { date : String
    , amount : Float
    , label : String
    }

type Page
    = GraphPage
    | EntryPage

type alias EntryForm =
    { date : String
    , amount : String
    , label : String
    }

type alias Model =
    { entries : List DayEntry
    , error : Maybe String
    , loading : Bool
    , page : Page
    , form : EntryForm
    , submitting : Bool
    , submitResult : Maybe (Result String String)
    , key : Nav.Key
    }

emptyForm : EntryForm
emptyForm =
    { date = "", amount = "", label = "" }

init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { entries = []
      , error = Nothing
      , loading = True
      , page = urlToPage url
      , form = emptyForm
      , submitting = False
      , submitResult = Nothing
      , key = key
      }
    , fetchData
    )

urlToPage : Url -> Page
urlToPage url =
    if String.contains "/entry" url.path then
        EntryPage
    else
        GraphPage


-- UPDATE

type Msg
    = GotData (Result Http.Error (List DayEntry))
    | Tick Time.Posix
    | UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | UpdateDate String
    | UpdateAmount String
    | UpdateLabel String
    | SubmitEntry
    | SubmitResult (Result Http.Error ())
    | ClearResult

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotData result ->
            case result of
                Ok entries ->
                    ( { model | entries = entries, loading = False, error = Nothing }
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

        UpdateDate val ->
            let f = model.form in
            ( { model | form = { f | date = val } }, Cmd.none )

        UpdateAmount val ->
            let f = model.form in
            ( { model | form = { f | amount = val } }, Cmd.none )

        UpdateLabel val ->
            let f = model.form in
            ( { model | form = { f | label = val } }, Cmd.none )

        SubmitEntry ->
            case String.toFloat model.form.amount of
                Nothing ->
                    ( { model | submitResult = Just (Err "Invalid amount") }, Cmd.none )

                Just amt ->
                    ( { model | submitting = True, submitResult = Nothing }
                    , submitEntry model.form.date amt model.form.label
                    )

        SubmitResult result ->
            case result of
                Ok _ ->
                    ( { model
                        | submitting = False
                        , submitResult = Just (Ok "Entry saved!")
                        , form = emptyForm
                      }
                    , fetchData
                    )

                Err err ->
                    ( { model
                        | submitting = False
                        , submitResult = Just (Err (httpErrorToString err))
                      }
                    , Cmd.none
                    )

        ClearResult ->
            ( { model | submitResult = Nothing }, Cmd.none )


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
            Time.every (30 * 1000) Tick  -- Refresh every 30 seconds on graph page

        EntryPage ->
            Sub.none


-- HTTP

fetchData : Cmd Msg
fetchData =
    Http.get
        { url = "/api/data"
        , expect = Http.expectJson GotData dataDecoder
        }

submitEntry : String -> Float -> String -> Cmd Msg
submitEntry date amount label =
    Http.post
        { url = "/api/entry"
        , body = Http.jsonBody (encodeEntry date amount label)
        , expect = Http.expectWhatever SubmitResult
        }

encodeEntry : String -> Float -> String -> Encode.Value
encodeEntry date amount label =
    Encode.object
        [ ( "date", Encode.string date )
        , ( "amount", Encode.float amount )
        , ( "label", Encode.string label )
        ]

dataDecoder : Decoder (List DayEntry)
dataDecoder =
    Decode.list entryDecoder

entryDecoder : Decoder DayEntry
entryDecoder =
    Decode.map3 DayEntry
        (Decode.field "date" Decode.string)
        (Decode.field "amount" Decode.float)
        (Decode.field "label" Decode.string)


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
        , style "padding" "40px"
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
            , style "font-size" "2em"
            ]
            [ text "Finance Tracker" ]
        , if model.loading then
            p [] [ text "Loading..." ]
          else
            case model.error of
                Just err ->
                    div []
                        [ p [ style "color" "#ff6b6b" ] [ text err ]
                        , p [ style "color" "#888" ] [ text "Will retry automatically..." ]
                        ]

                Nothing ->
                    viewGraph model.entries
        ]

viewEntryPage : Model -> Html Msg
viewEntryPage model =
    div []
        [ div
            [ style "display" "flex"
            , style "justify-content" "space-between"
            , style "align-items" "center"
            , style "margin-bottom" "30px"
            ]
            [ h1
                [ style "margin" "0"
                , style "font-weight" "300"
                , style "font-size" "2em"
                ]
                [ text "Add Entry" ]
            , a
                [ href "/"
                , style "color" "#4facfe"
                , style "text-decoration" "none"
                ]
                [ text "View Graph" ]
            ]
        , viewEntryForm model
        , viewRecentEntries model.entries
        ]

viewEntryForm : Model -> Html Msg
viewEntryForm model =
    div
        [ style "background" "#252542"
        , style "padding" "30px"
        , style "border-radius" "12px"
        , style "max-width" "400px"
        ]
        [ viewFormField "Date" "date" model.form.date UpdateDate "2025-01-02"
        , viewFormField "Amount" "number" model.form.amount UpdateAmount "0.00"
        , viewFormField "Label" "text" model.form.label UpdateLabel "e.g., Day's pay"
        , button
            [ onClick SubmitEntry
            , style "width" "100%"
            , style "padding" "15px"
            , style "margin-top" "10px"
            , style "background" "linear-gradient(to right, #4facfe, #00f2fe)"
            , style "border" "none"
            , style "border-radius" "8px"
            , style "color" "#1a1a2e"
            , style "font-size" "1.1em"
            , style "font-weight" "600"
            , style "cursor" "pointer"
            ]
            [ text (if model.submitting then "Saving..." else "Add Entry") ]
        , case model.submitResult of
            Nothing ->
                text ""

            Just (Ok msg) ->
                p [ style "color" "#4ade80", style "margin-top" "15px" ] [ text msg ]

            Just (Err msg) ->
                p [ style "color" "#ff6b6b", style "margin-top" "15px" ] [ text msg ]
        ]

viewFormField : String -> String -> String -> (String -> Msg) -> String -> Html Msg
viewFormField labelText inputType val toMsg placeholderText =
    div [ style "margin-bottom" "20px" ]
        [ label
            [ style "display" "block"
            , style "margin-bottom" "8px"
            , style "color" "#888"
            , style "font-size" "0.9em"
            ]
            [ text labelText ]
        , input
            [ type_ inputType
            , value val
            , onInput toMsg
            , placeholder placeholderText
            , style "width" "100%"
            , style "padding" "12px"
            , style "background" "#1a1a2e"
            , style "border" "1px solid #333"
            , style "border-radius" "6px"
            , style "color" "#eee"
            , style "font-size" "1em"
            , style "box-sizing" "border-box"
            , if inputType == "number" then step "0.01" else style "" ""
            ]
            []
        ]

viewRecentEntries : List DayEntry -> Html Msg
viewRecentEntries entries =
    let
        recent = List.take 5 (List.reverse entries)
    in
    if List.isEmpty recent then
        text ""
    else
        div [ style "margin-top" "40px" ]
            [ h2
                [ style "font-weight" "300"
                , style "font-size" "1.2em"
                , style "margin-bottom" "15px"
                , style "color" "#888"
                ]
                [ text "Recent Entries" ]
            , div [] (List.map viewRecentEntry recent)
            ]

viewRecentEntry : DayEntry -> Html Msg
viewRecentEntry entry =
    div
        [ style "display" "flex"
        , style "justify-content" "space-between"
        , style "padding" "12px 0"
        , style "border-bottom" "1px solid #333"
        ]
        [ div []
            [ div [ style "color" "#eee" ] [ text entry.label ]
            , div [ style "color" "#666", style "font-size" "0.85em" ] [ text entry.date ]
            ]
        , div
            [ style "color" "#4facfe"
            , style "font-weight" "500"
            ]
            [ text ("$" ++ formatAmount entry.amount) ]
        ]


viewGraph : List DayEntry -> Html Msg
viewGraph entries =
    if List.isEmpty entries then
        p [ style "color" "#888" ] [ text "No data yet. Add entries at /entry" ]
    else
        let
            amounts = List.map .amount entries
            maxAmount = Maybe.withDefault 100 (List.maximum amounts)
            minAmount = Maybe.withDefault 0 (List.minimum amounts)
            range = max (maxAmount - minAmount) 1
        in
        div []
            [ div
                [ style "display" "flex"
                , style "align-items" "flex-end"
                , style "height" "400px"
                , style "gap" "4px"
                , style "padding" "20px 0"
                , style "border-bottom" "2px solid #333"
                ]
                (List.map (viewBar minAmount range) entries)
            , viewLatest entries
            ]

viewBar : Float -> Float -> DayEntry -> Html Msg
viewBar minAmount range entry =
    let
        normalizedHeight = (entry.amount - minAmount) / range
        heightPercent = max 5 (normalizedHeight * 100)
    in
    div
        [ style "flex" "1"
        , style "min-width" "20px"
        , style "max-width" "60px"
        , style "height" (String.fromFloat heightPercent ++ "%")
        , style "background" "linear-gradient(to top, #4facfe, #00f2fe)"
        , style "border-radius" "4px 4px 0 0"
        , style "position" "relative"
        , style "cursor" "default"
        ]
        [ div
            [ style "position" "absolute"
            , style "bottom" "-25px"
            , style "left" "50%"
            , style "transform" "translateX(-50%)"
            , style "font-size" "10px"
            , style "color" "#888"
            , style "white-space" "nowrap"
            ]
            [ text (String.right 5 entry.date) ]
        ]

viewLatest : List DayEntry -> Html Msg
viewLatest entries =
    case List.head (List.reverse entries) of
        Nothing ->
            text ""

        Just latest ->
            div
                [ style "margin-top" "40px"
                , style "text-align" "center"
                ]
                [ p
                    [ style "font-size" "3em"
                    , style "margin" "0"
                    , style "color" "#4facfe"
                    ]
                    [ text ("$" ++ formatAmount latest.amount) ]
                , p
                    [ style "color" "#888"
                    , style "margin" "10px 0 0 0"
                    ]
                    [ text latest.label ]
                ]

formatAmount : Float -> String
formatAmount amount =
    let
        intPart = floor amount
        decPart = round ((amount - toFloat intPart) * 100)
        decStr = if decPart < 10 then "0" ++ String.fromInt decPart else String.fromInt decPart
    in
    String.fromInt intPart ++ "." ++ decStr
