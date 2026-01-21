module Api.Types exposing (..)

{-| Auto-generated from Rust types. DO NOT EDIT MANUALLY.

    To regenerate, run: make generate-elm
    (or: cd backend && cargo run --bin generate-elm)
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias Job =
    { id : String
    , name : String
    }


jobDecoder : Decode.Decoder Job
jobDecoder =
    Decode.succeed Job
        |> Decode.andThen (\x -> Decode.map x (Decode.field "id" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "name" (Decode.string)))


jobEncoder : Job -> Encode.Value
jobEncoder struct =
    Encode.object
        [ ( "id", (Encode.string) struct.id )
        , ( "name", (Encode.string) struct.name )
        ]


type alias WorkLog =
    { id : Int
    , date : String
    , jobId : String
    , hours : Float
    , payRate : Float
    , taxRate : Float
    , payCashed : Bool
    }


workLogDecoder : Decode.Decoder WorkLog
workLogDecoder =
    Decode.succeed WorkLog
        |> Decode.andThen (\x -> Decode.map x (Decode.field "id" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "jobId" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "hours" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payRate" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "taxRate" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payCashed" (Decode.bool)))


workLogEncoder : WorkLog -> Encode.Value
workLogEncoder struct =
    Encode.object
        [ ( "id", (Encode.int) struct.id )
        , ( "date", (Encode.string) struct.date )
        , ( "jobId", (Encode.string) struct.jobId )
        , ( "hours", (Encode.float) struct.hours )
        , ( "payRate", (Encode.float) struct.payRate )
        , ( "taxRate", (Encode.float) struct.taxRate )
        , ( "payCashed", (Encode.bool) struct.payCashed )
        ]


type alias NewWorkLog =
    { date : String
    , jobId : String
    , hours : Float
    , payRate : Float
    , taxRate : Float
    , payCashed : Bool
    }


newWorkLogDecoder : Decode.Decoder NewWorkLog
newWorkLogDecoder =
    Decode.succeed NewWorkLog
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "jobId" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "hours" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payRate" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "taxRate" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "payCashed" (Decode.bool)))


newWorkLogEncoder : NewWorkLog -> Encode.Value
newWorkLogEncoder struct =
    Encode.object
        [ ( "date", (Encode.string) struct.date )
        , ( "jobId", (Encode.string) struct.jobId )
        , ( "hours", (Encode.float) struct.hours )
        , ( "payRate", (Encode.float) struct.payRate )
        , ( "taxRate", (Encode.float) struct.taxRate )
        , ( "payCashed", (Encode.bool) struct.payCashed )
        ]


type alias BalanceSnapshot =
    { id : Int
    , date : String
    , checking : Float
    , creditAvailable : Float
    , creditLimit : Float
    , personalDebt : Float
    , note : String
    }


balanceSnapshotDecoder : Decode.Decoder BalanceSnapshot
balanceSnapshotDecoder =
    Decode.succeed BalanceSnapshot
        |> Decode.andThen (\x -> Decode.map x (Decode.field "id" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "checking" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditAvailable" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditLimit" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "personalDebt" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "note" (Decode.string)))


balanceSnapshotEncoder : BalanceSnapshot -> Encode.Value
balanceSnapshotEncoder struct =
    Encode.object
        [ ( "id", (Encode.int) struct.id )
        , ( "date", (Encode.string) struct.date )
        , ( "checking", (Encode.float) struct.checking )
        , ( "creditAvailable", (Encode.float) struct.creditAvailable )
        , ( "creditLimit", (Encode.float) struct.creditLimit )
        , ( "personalDebt", (Encode.float) struct.personalDebt )
        , ( "note", (Encode.string) struct.note )
        ]


type alias NewBalanceSnapshot =
    { date : String
    , checking : Float
    , creditAvailable : Float
    , creditLimit : Float
    , personalDebt : Float
    , note : String
    }


newBalanceSnapshotDecoder : Decode.Decoder NewBalanceSnapshot
newBalanceSnapshotDecoder =
    Decode.succeed NewBalanceSnapshot
        |> Decode.andThen (\x -> Decode.map x (Decode.field "date" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "checking" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditAvailable" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "creditLimit" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "personalDebt" (Decode.float)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "note" (Decode.string)))


newBalanceSnapshotEncoder : NewBalanceSnapshot -> Encode.Value
newBalanceSnapshotEncoder struct =
    Encode.object
        [ ( "date", (Encode.string) struct.date )
        , ( "checking", (Encode.float) struct.checking )
        , ( "creditAvailable", (Encode.float) struct.creditAvailable )
        , ( "creditLimit", (Encode.float) struct.creditLimit )
        , ( "personalDebt", (Encode.float) struct.personalDebt )
        , ( "note", (Encode.string) struct.note )
        ]


type alias FinanceData =
    { jobs : List (Job)
    , workLogs : List (WorkLog)
    , balanceSnapshots : List (BalanceSnapshot)
    }


financeDataDecoder : Decode.Decoder FinanceData
financeDataDecoder =
    Decode.succeed FinanceData
        |> Decode.andThen (\x -> Decode.map x (Decode.field "jobs" (Decode.list (jobDecoder))))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "workLogs" (Decode.list (workLogDecoder))))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "balanceSnapshots" (Decode.list (balanceSnapshotDecoder))))


financeDataEncoder : FinanceData -> Encode.Value
financeDataEncoder struct =
    Encode.object
        [ ( "jobs", (Encode.list (jobEncoder)) struct.jobs )
        , ( "workLogs", (Encode.list (workLogEncoder)) struct.workLogs )
        , ( "balanceSnapshots", (Encode.list (balanceSnapshotEncoder)) struct.balanceSnapshots )
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
    { currentF : Int
    , highF : Int
    , lowF : Int
    }


weatherDecoder : Decode.Decoder Weather
weatherDecoder =
    Decode.succeed Weather
        |> Decode.andThen (\x -> Decode.map x (Decode.field "currentF" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "highF" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "lowF" (Decode.int)))


weatherEncoder : Weather -> Encode.Value
weatherEncoder struct =
    Encode.object
        [ ( "currentF", (Encode.int) struct.currentF )
        , ( "highF", (Encode.int) struct.highF )
        , ( "lowF", (Encode.int) struct.lowF )
        ]


