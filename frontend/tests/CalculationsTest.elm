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
        , describe "Pay cashed scenario - payCashed means previous week is paid, count only current week"
            [ test "12/28 (Sat) - no payCashed in week 12/22-12/28, count current + previous week" <|
                \_ ->
                    let
                        -- 12/28 is Saturday, its week is 12/22 (Sun) - 12/28 (Sat)
                        -- Previous week is 12/15-12/21
                        -- No payCashed anywhere, so count both weeks
                        -- Only entry in range is 12/28 itself = 2h * $10 = $20
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]
                        targetEntry = makeEntry 1 "2024-12-28" 2 10 False
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 20 incomingPay
            , test "12/29 (Sun) - no payCashed yet in week 12/29-1/4, count current + previous week" <|
                \_ ->
                    let
                        -- 12/29 is Sunday, starts new week 12/29-1/4
                        -- Previous week is 12/22-12/28 (has 12/28 entry with 2h)
                        -- No payCashed visible yet (1/1 is in the future relative to 12/29)
                        -- Count: previous week (12/28 = 2h) + current week (12/29 = 2h) = 4h * $10 = $40
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]
                        targetEntry = makeEntry 2 "2024-12-29" 2 10 False
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 40 incomingPay
            , test "1/1 (Wed) with payCashed - current week has payCashed, count ONLY current week from Sunday" <|
                \_ ->
                    let
                        -- 1/1 is Wednesday, week is 12/29-1/4
                        -- payCashed=true on 1/1 means: previous week (12/22-12/28) is PAID
                        -- So count only current week: 12/29 (2h) + 1/1 (1h) = 3h * $10 = $30
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]
                        targetEntry = makeEntry 3 "2025-01-01" 1 10 True
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 30 incomingPay
            , test "1/2 (Thu) - payCashed exists earlier in week, count ONLY current week from Sunday" <|
                \_ ->
                    let
                        -- 1/2 is Thursday, week is 12/29-1/4
                        -- payCashed=true on 1/1 (earlier in this week)
                        -- Count only current week: 12/29 (2h) + 1/1 (1h) + 1/2 (1h) = 4h * $10 = $40
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]
                        targetEntry = makeEntry 4 "2025-01-02" 1 10 False
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 40 incomingPay
            , test "1/3 (Fri) - payCashed exists earlier in week, count ONLY current week from Sunday" <|
                \_ ->
                    let
                        -- 1/3 is Friday, week is 12/29-1/4
                        -- payCashed=true on 1/1 (earlier in this week)
                        -- Count only current week: 12/29 (2h) + 1/1 (1h) + 1/2 (1h) + 1/3 (1h) = 5h * $10 = $50
                        entries =
                            [ makeEntry 1 "2024-12-28" 2 10 False
                            , makeEntry 2 "2024-12-29" 2 10 False
                            , makeEntry 3 "2025-01-01" 1 10 True
                            , makeEntry 4 "2025-01-02" 1 10 False
                            , makeEntry 5 "2025-01-03" 1 10 False
                            ]
                        targetEntry = makeEntry 5 "2025-01-03" 1 10 False
                        incomingPay = incomingPayForEntry targetEntry entries
                    in
                    Expect.within (Expect.Absolute 0.01) 50 incomingPay
            ]
        ]
