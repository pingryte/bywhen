module MainTest exposing (suite)

import Expect
import Main exposing (Frequency(..), frequencyToString)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Savings form domain values"
        [ test "monthly frequency uses the Rust wire format" <|
            \_ -> Expect.equal "monthly" (frequencyToString Monthly)
        , test "fortnightly frequency is not represented as an arbitrary label" <|
            \_ -> Expect.equal "fortnightly" (frequencyToString Fortnightly)
        ]
