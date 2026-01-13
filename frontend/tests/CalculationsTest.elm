module CalculationsTest exposing (..)

import Calculations exposing (dateToDays, daysToDateString, dayOfWeekName, incomingPayForEntry, dateToWeekNumber, calculateDailyPay)
import Api.Types exposing (Entry)
import Expect
import Test exposing (..)


-- Tax multiplier used in calculations (25% tax withheld)
taxMultiplier : Float
taxMultiplier = 0.75


-- Helper to create an entry with minimal fields
makeEntry : Int -> String -> Float -> Float -> Bool -> Entry
makeEntry id date hoursWorked payPerHour payCashed =
    { id = id
    , date = date
    , checking = 0
    , creditAvailable = 0
    , creditLimit = 0
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
        , describe "Daily overtime calculations (Alaska rules)"
            [ test "8 hours = all regular, no overtime" <|
                \_ ->
                    -- 8h * $10 * 0.75 tax = $60
                    let
                        result = calculateDailyPay 8 10 0
                    in
                    Expect.within (Expect.Absolute 0.01) 60 result
            , test "10 hours = 8 regular + 2 OT" <|
                \_ ->
                    -- (8h * $10 + 2h * $10 * 1.5) * 0.75 = (80 + 30) * 0.75 = $82.50
                    let
                        result = calculateDailyPay 10 10 0
                    in
                    Expect.within (Expect.Absolute 0.01) 82.50 result
            , test "12 hours = 8 regular + 4 OT" <|
                \_ ->
                    -- (8h * $10 + 4h * $10 * 1.5) * 0.75 = (80 + 60) * 0.75 = $105
                    let
                        result = calculateDailyPay 12 10 0
                    in
                    Expect.within (Expect.Absolute 0.01) 105 result
            , test "4 hours = all regular" <|
                \_ ->
                    -- 4h * $10 * 0.75 = $30
                    let
                        result = calculateDailyPay 4 10 0
                    in
                    Expect.within (Expect.Absolute 0.01) 30 result
            ]
        , describe "Weekly overtime calculations (40hr threshold)"
            [ test "Day 1: 8h, accumulated 0h = all regular" <|
                \_ ->
                    -- First day of week, no accumulated hours
                    -- 8h * $10 * 0.75 = $60
                    let
                        result = calculateDailyPay 8 10 0
                    in
                    Expect.within (Expect.Absolute 0.01) 60 result
            , test "Day 6 (Sat): 8h, accumulated 40h = all weekly OT" <|
                \_ ->
                    -- Already hit 40h threshold from previous days
                    -- 8h all at OT rate: 8h * $10 * 1.5 * 0.75 = $90
                    let
                        result = calculateDailyPay 8 10 40
                    in
                    Expect.within (Expect.Absolute 0.01) 90 result
            , test "Day 5 (Fri): 8h, accumulated 32h = all regular (hits 40 exactly)" <|
                \_ ->
                    -- 32h accumulated, 8h today = 40h total, all still regular
                    -- 8h * $10 * 0.75 = $60
                    let
                        result = calculateDailyPay 8 10 32
                    in
                    Expect.within (Expect.Absolute 0.01) 60 result
            , test "Day 5: 10h, accumulated 32h = 8 reg + 2 daily OT (weekly threshold at 40, but daily OT kicks in)" <|
                \_ ->
                    -- 32h accumulated + 10h today
                    -- Daily: 8h regular, 2h daily OT (over 8h)
                    -- Weekly: 32 + 8 = 40, exactly at threshold, so 8h is regular
                    -- Result: 8h reg + 2h OT = (8*10 + 2*10*1.5) * 0.75 = (80 + 30) * 0.75 = $82.50
                    let
                        result = calculateDailyPay 10 10 32
                    in
                    Expect.within (Expect.Absolute 0.01) 82.50 result
            , test "Day 5: 8h, accumulated 36h = 4 reg + 4 weekly OT" <|
                \_ ->
                    -- 36h accumulated + 8h today = 44h total
                    -- Daily: all 8h are regular rate (not over 8)
                    -- Weekly: 36 + 4 = 40, then 4 more become weekly OT
                    -- Result: 4h reg + 4h OT = (4*10 + 4*10*1.5) * 0.75 = (40 + 60) * 0.75 = $75
                    let
                        result = calculateDailyPay 8 10 36
                    in
                    Expect.within (Expect.Absolute 0.01) 75 result
            , test "Day 6: 10h, accumulated 40h = 8h weekly OT + 2h daily OT (both apply)" <|
                \_ ->
                    -- Already at 40h, everything is OT
                    -- Daily: 8h base + 2h daily OT, but all already at weekly OT rate
                    -- All 10h at OT: 10h * $10 * 1.5 * 0.75 = $112.50
                    let
                        result = calculateDailyPay 10 10 40
                    in
                    Expect.within (Expect.Absolute 0.01) 112.50 result
            ]
        , describe "Pay cashed scenario - payCashed means previous week is paid, count only current week"
            [ test "12/28 (Sat) - no payCashed in week 12/22-12/28, count current + previous week" <|
                \_ ->
                    let
                        -- 12/28 is Saturday, its week is 12/22 (Sun) - 12/28 (Sat)
                        -- Previous week is 12/15-12/21
                        -- No payCashed anywhere, so count both weeks
                        -- Only entry in range is 12/28 itself = 2h * $10 * 0.75 = $15
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
                    Expect.within (Expect.Absolute 0.01) 15 incomingPay
            , test "12/29 (Sun) - no payCashed yet in week 12/29-1/4, count current + previous week" <|
                \_ ->
                    let
                        -- 12/29 is Sunday, starts new week 12/29-1/4
                        -- Previous week is 12/22-12/28 (has 12/28 entry with 2h)
                        -- No payCashed visible yet (1/1 is in the future relative to 12/29)
                        -- Count: previous week (12/28 = 2h) + current week (12/29 = 2h) = 4h * $10 * 0.75 = $30
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
                    Expect.within (Expect.Absolute 0.01) 30 incomingPay
            , test "1/1 (Wed) with payCashed - current week has payCashed, count ONLY current week from Sunday" <|
                \_ ->
                    let
                        -- 1/1 is Wednesday, week is 12/29-1/4
                        -- payCashed=true on 1/1 means: previous week (12/22-12/28) is PAID
                        -- So count only current week: 12/29 (2h) + 1/1 (1h) = 3h * $10 * 0.75 = $22.50
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
                    Expect.within (Expect.Absolute 0.01) 22.50 incomingPay
            , test "1/2 (Thu) - payCashed exists earlier in week, count ONLY current week from Sunday" <|
                \_ ->
                    let
                        -- 1/2 is Thursday, week is 12/29-1/4
                        -- payCashed=true on 1/1 (earlier in this week)
                        -- Count only current week: 12/29 (2h) + 1/1 (1h) + 1/2 (1h) = 4h * $10 * 0.75 = $30
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
                    Expect.within (Expect.Absolute 0.01) 30 incomingPay
            , test "1/3 (Fri) - payCashed exists earlier in week, count ONLY current week from Sunday" <|
                \_ ->
                    let
                        -- 1/3 is Friday, week is 12/29-1/4
                        -- payCashed=true on 1/1 (earlier in this week)
                        -- Count only current week: 12/29 (2h) + 1/1 (1h) + 1/2 (1h) + 1/3 (1h) = 5h * $10 * 0.75 = $37.50
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
                    Expect.within (Expect.Absolute 0.01) 37.50 incomingPay
            ]
        ]
