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
    , checking : Float
    , creditAvailable : Float
    , creditLimit : Float
    , hoursWorked : Float
    , payPerHour : Float
    , otherIncoming : Float
    , personalDebt : Float
    , note : String
    , payCashed : Bool
    }


entryDecoder : Decode.Decoder Entry
entryDecoder =
    Decode.succeed Entry
        |> Decode.andThen (\x -> Decode.map x (Decode.field "id" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "checking" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditAvailable" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditLimit" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "hoursWorked" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payPerHour" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "otherIncoming" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "personalDebt" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "note" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payCashed" (Decode.bool)))


entryEncoder : Entry -> Encode.Value
entryEncoder struct =
    Encode.object
        [ ( "id", (Encode.int) struct.id )
        , ( "date", (Encode.string) struct.date )
        , ( "checking", (Encode.float) struct.checking )
        , ( "creditAvailable", (Encode.float) struct.creditAvailable )
        , ( "creditLimit", (Encode.float) struct.creditLimit )
        , ( "hoursWorked", (Encode.float) struct.hoursWorked )
        , ( "payPerHour", (Encode.float) struct.payPerHour )
        , ( "otherIncoming", (Encode.float) struct.otherIncoming )
        , ( "personalDebt", (Encode.float) struct.personalDebt )
        , ( "note", (Encode.string) struct.note )
        , ( "payCashed", (Encode.bool) struct.payCashed )
        ]


type alias NewEntry =
    { date : String
    , checking : Float
    , creditAvailable : Float
    , creditLimit : Float
    , hoursWorked : Float
    , payPerHour : Float
    , otherIncoming : Float
    , personalDebt : Float
    , note : String
    , payCashed : Bool
    }


newEntryDecoder : Decode.Decoder NewEntry
newEntryDecoder =
    Decode.succeed NewEntry
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "checking" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditAvailable" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditLimit" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "hoursWorked" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payPerHour" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "otherIncoming" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "personalDebt" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "note" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payCashed" (Decode.bool)))


newEntryEncoder : NewEntry -> Encode.Value
newEntryEncoder struct =
    Encode.object
        [ ( "date", (Encode.string) struct.date )
        , ( "checking", (Encode.float) struct.checking )
        , ( "creditAvailable", (Encode.float) struct.creditAvailable )
        , ( "creditLimit", (Encode.float) struct.creditLimit )
        , ( "hoursWorked", (Encode.float) struct.hoursWorked )
        , ( "payPerHour", (Encode.float) struct.payPerHour )
        , ( "otherIncoming", (Encode.float) struct.otherIncoming )
        , ( "personalDebt", (Encode.float) struct.personalDebt )
        , ( "note", (Encode.string) struct.note )
        , ( "payCashed", (Encode.bool) struct.payCashed )
        ]


type alias ApiResponse =
    { ok : Bool
    }


apiResponseEncoder : ApiResponse -> Encode.Value
apiResponseEncoder struct =
    Encode.object
        [ ( "ok", (Encode.bool) struct.ok )
        ]


type alias Weather =
    { highF : Int
    , lowF : Int
    }


weatherDecoder : Decode.Decoder Weather
weatherDecoder =
    Decode.succeed Weather
        |> Decode.andThen (\x -> Decode.map x (Decode.field "highF" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "lowF" (Decode.int)))


weatherEncoder : Weather -> Encode.Value
weatherEncoder struct =
    Encode.object
        [ ( "highF", (Encode.int) struct.highF )
        , ( "lowF", (Encode.int) struct.lowF )
        ]


