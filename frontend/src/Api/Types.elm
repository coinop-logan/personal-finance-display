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


type alias ForecastPeriod =
    { name : String
    , temperature : Int
    , temperatureUnit : String
    , windSpeed : String
    , windDirection : String
    , shortForecast : String
    , detailedForecast : String
    , precipitationChance : Maybe (Int)
    , isDaytime : Bool
    }


forecastPeriodDecoder : Decode.Decoder ForecastPeriod
forecastPeriodDecoder =
    Decode.succeed ForecastPeriod
        |> Decode.andThen (\x -> Decode.map x (Decode.field "name" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "temperature" (Decode.int)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "temperatureUnit" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "windSpeed" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "windDirection" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "shortForecast" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "detailedForecast" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "precipitationChance" (Decode.nullable (Decode.int))))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "isDaytime" (Decode.bool)))


forecastPeriodEncoder : ForecastPeriod -> Encode.Value
forecastPeriodEncoder struct =
    Encode.object
        [ ( "name", (Encode.string) struct.name )
        , ( "temperature", (Encode.int) struct.temperature )
        , ( "temperatureUnit", (Encode.string) struct.temperatureUnit )
        , ( "windSpeed", (Encode.string) struct.windSpeed )
        , ( "windDirection", (Encode.string) struct.windDirection )
        , ( "shortForecast", (Encode.string) struct.shortForecast )
        , ( "detailedForecast", (Encode.string) struct.detailedForecast )
        , ( "precipitationChance", (Maybe.withDefault Encode.null << Maybe.map (Encode.int)) struct.precipitationChance )
        , ( "isDaytime", (Encode.bool) struct.isDaytime )
        ]


type alias WeatherAlert =
    { event : String
    , severity : String
    , headline : String
    , description : String
    , instruction : Maybe (String)
    , areas : String
    , ends : Maybe (String)
    }


weatherAlertDecoder : Decode.Decoder WeatherAlert
weatherAlertDecoder =
    Decode.succeed WeatherAlert
        |> Decode.andThen (\x -> Decode.map x (Decode.field "event" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "severity" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "headline" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "description" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "instruction" (Decode.nullable (Decode.string))))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "areas" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "ends" (Decode.nullable (Decode.string))))


weatherAlertEncoder : WeatherAlert -> Encode.Value
weatherAlertEncoder struct =
    Encode.object
        [ ( "event", (Encode.string) struct.event )
        , ( "severity", (Encode.string) struct.severity )
        , ( "headline", (Encode.string) struct.headline )
        , ( "description", (Encode.string) struct.description )
        , ( "instruction", (Maybe.withDefault Encode.null << Maybe.map (Encode.string)) struct.instruction )
        , ( "areas", (Encode.string) struct.areas )
        , ( "ends", (Maybe.withDefault Encode.null << Maybe.map (Encode.string)) struct.ends )
        ]


type alias WeatherBriefing =
    { generatedAt : String
    , alerts : List (WeatherAlert)
    , forecastPeriods : List (ForecastPeriod)
    }


weatherBriefingDecoder : Decode.Decoder WeatherBriefing
weatherBriefingDecoder =
    Decode.succeed WeatherBriefing
        |> Decode.andThen (\x -> Decode.map x (Decode.field "generatedAt" (Decode.string)))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "alerts" (Decode.list (weatherAlertDecoder))))
        |> Decode.andThen (\x -> Decode.map x (Decode.field "forecastPeriods" (Decode.list (forecastPeriodDecoder))))


weatherBriefingEncoder : WeatherBriefing -> Encode.Value
weatherBriefingEncoder struct =
    Encode.object
        [ ( "generatedAt", (Encode.string) struct.generatedAt )
        , ( "alerts", (Encode.list (weatherAlertEncoder)) struct.alerts )
        , ( "forecastPeriods", (Encode.list (forecastPeriodEncoder)) struct.forecastPeriods )
        ]


