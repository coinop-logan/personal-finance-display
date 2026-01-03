module CalculationsTest exposing (..)

import Calculations exposing (dateToDays, daysToDateString, dayOfWeekName, incomingPayForEntry, dateToWeekNumber)
import Api.Types exposing (Entry)
import Expect
import Test exposing (..)


-- Helper to create an entry with minimal fields
makeEntry : Int -> String -> Float -> Float -> Bool -> Entry
makeEntry id date hoursWorked payPerHour payCashed =
    { id = id
    , date = date
    , checking = 0
    , creditAvailable = 0
    , hoursWorked = hoursWorked
    , payPerHour = payPerHour
    , otherIncoming = 0
    , personalDebt = 0
    , note = ""
    , payCashed = payCashed
    }


suite : Test
suite =
    describe "Calculations"
        [ describe "Date helpers"
            [ test "dateToDays for 2000-01-01 is 0" <|
                \_ ->
                    Expect.equal 0 (dateToDays "2000-01-01")
            , test "dateToDays for 2000-01-02 is 1" <|
                \_ ->
                    Expect.equal 1 (dateToDays "2000-01-02")
            , test "dayOfWeekName for 2000-01-01 (day 0) is Sat" <|
                \_ ->
                    Expect.equal "Sat" (dayOfWeekName 0)
            , test "dayOfWeekName for 2000-01-02 (day 1) is Sun" <|
                \_ ->
                    Expect.equal "Sun" (dayOfWeekName 1)
            , test "2024-12-28 is Saturday" <|
                \_ ->
                    Expect.equal "Sat" (dayOfWeekName (dateToDays "2024-12-28"))
            , test "2024-12-29 is Sunday" <|
                \_ ->
                    Expect.equal "Sun" (dayOfWeekName (dateToDays "2024-12-29"))
            , test "2025-01-01 is Wednesday" <|
                \_ ->
                    Expect.equal "Wed" (dayOfWeekName (dateToDays "2025-01-01"))
            ]
        , describe "Pay cashed scenario"
            [ test "Same scenario - viewing 12/28 row (before payCashed exists)" <|
                \_ ->
                    let
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]

                        -- Target: the 12/28 row
                        targetEntry = makeEntry 1 "2024-12-28" 2 10 False

                        -- On 12/28, we can only see entries up to 12/28
                        -- 12/28 is Saturday. Sunday of that week is 12/22.
                        -- No payCashed in current week (12/22-12/28), so we also count previous week (12/15-12/21)
                        -- But there are no entries in those weeks except 12/28 itself
                        -- So incoming = 2 hours * $10 = $20
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 20 incomingPay
            , test "Same scenario - viewing 12/29 row" <|
                \_ ->
                    let
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]

                        -- Target: the 12/29 row
                        targetEntry = makeEntry 2 "2024-12-29" 2 10 False

                        -- On 12/29 (Sunday), current week starts 12/29
                        -- Previous week is 12/22-12/28
                        -- No payCashed visible yet (1/1 is in the future)
                        -- So we count: previous week (12/28 = 2h) + current week (12/29 = 2h) = 4h * $10 = $40
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 40 incomingPay
            , test "Same scenario - viewing 1/1 row (the one with payCashed)" <|
                \_ ->
                    let
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]

                        -- Target: the 1/1 row (has payCashed=true)
                        targetEntry = makeEntry 3 "2025-01-01" 1 10 True

                        -- payCashed on 1/1 means: only count hours FROM 1/1 onward
                        -- So incoming = just 1/1 (1h) = $10
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 10 incomingPay
            , test "Same scenario - viewing 1/2 row (day after payCashed)" <|
                \_ ->
                    let
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]

                        -- Target: the 1/2 row
                        targetEntry = makeEntry 4 "2025-01-02" 1 10 False

                        -- payCashed on 1/1 means: only count hours FROM 1/1 onward
                        -- So incoming = 1/1 (1h) + 1/2 (1h) = 2h * $10 = $20
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 20 incomingPay
            , test "Same scenario - viewing 1/3 row" <|
                \_ ->
                    let
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]

                        -- Target: the 1/3 row
                        targetEntry = makeEntry 5 "2025-01-03" 1 10 False

                        -- payCashed on 1/1 means: only count hours FROM 1/1 onward
                        -- So incoming = 1/1 (1h) + 1/2 (1h) + 1/3 (1h) = 3h * $10 = $30
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 30 incomingPay
            ]
        ]
