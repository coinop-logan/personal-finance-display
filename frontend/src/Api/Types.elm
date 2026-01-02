module Api.Types exposing (..)

{-| Auto-generated from Rust types. DO NOT EDIT MANUALLY.

    To regenerate, run: make generate-elm
    (or: cd backend && cargo run --bin generate-elm)
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias Entry =
    { id : Int
    , date : String
    , timestamp : Int
    , checking : Float
    , creditAvailable : Float
    , hoursWorked : Float
    , payPerHour : Float
    , otherIncoming : Float
    , note : String
    }


entryDecoder : Decode.Decoder Entry
entryDecoder =
    Decode.succeed Entry
        |> Decode.andThen (\x -> Decode.map x (Decode.field "id" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "timestamp" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "checking" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditAvailable" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "hoursWorked" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payPerHour" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "otherIncoming" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "note" (Decode.string)))


entryEncoder : Entry -> Encode.Value
entryEncoder struct =
    Encode.object
        [ ( "id", (Encode.int) struct.id )
        , ( "date", (Encode.string) struct.date )
        , ( "timestamp", (Encode.int) struct.timestamp )
        , ( "checking", (Encode.float) struct.checking )
        , ( "creditAvailable", (Encode.float) struct.creditAvailable )
        , ( "hoursWorked", (Encode.float) struct.hoursWorked )
        , ( "payPerHour", (Encode.float) struct.payPerHour )
        , ( "otherIncoming", (Encode.float) struct.otherIncoming )
        , ( "note", (Encode.string) struct.note )
        ]


type alias NewEntry =
    { date : String
    , checking : Float
    , creditAvailable : Float
    , hoursWorked : Float
    , payPerHour : Float
    , otherIncoming : Float
    , note : String
    }


newEntryDecoder : Decode.Decoder NewEntry
newEntryDecoder =
    Decode.succeed NewEntry
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "checking" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditAvailable" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "hoursWorked" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payPerHour" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "otherIncoming" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "note" (Decode.string)))


newEntryEncoder : NewEntry -> Encode.Value
newEntryEncoder struct =
    Encode.object
        [ ( "date", (Encode.string) struct.date )
        , ( "checking", (Encode.float) struct.checking )
        , ( "creditAvailable", (Encode.float) struct.creditAvailable )
        , ( "hoursWorked", (Encode.float) struct.hoursWorked )
        , ( "payPerHour", (Encode.float) struct.payPerHour )
        , ( "otherIncoming", (Encode.float) struct.otherIncoming )
        , ( "note", (Encode.string) struct.note )
        ]


type alias ApiResponse =
    { ok : Bool
    }


apiResponseEncoder : ApiResponse -> Encode.Value
apiResponseEncoder struct =
    Encode.object
        [ ( "ok", (Encode.bool) struct.ok )
        ]


