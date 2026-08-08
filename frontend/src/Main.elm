port module Main exposing (Frequency(..), frequencyToString, main)

import Browser
import Html exposing (Html, a, button, div, footer, h1, h2, header, input, label, main_, option, p, progress, section, select, span, text)
import Html.Attributes exposing (attribute, class, classList, for, href, id, selected, step, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


port calculateGoal : Encode.Value -> Cmd msg


port calculationReceived : (Decode.Value -> msg) -> Sub msg


port saveLocalGoal : Encode.Value -> Cmd msg


port requestLocalGoals : () -> Cmd msg


port localGoalsReceived : (Decode.Value -> msg) -> Sub msg


port copyResult : String -> Cmd msg


port networkStatus : (Bool -> msg) -> Sub msg


port createSharedGoal : Encode.Value -> Cmd msg


port sharedGoalCreated : (String -> msg) -> Sub msg


port sharedGoalReceived : (Decode.Value -> msg) -> Sub msg


type GoalType
    = Savings
    | Debt
    | ProgressGoal
    | Repetition
    | Countdown
    | Generic


type Frequency
    = Daily
    | Weekly
    | Fortnightly
    | Monthly
    | Yearly


type Currency
    = GBP
    | USD
    | EUR


type alias Model =
    { goalType : GoalType
    , reverse : Bool
    , target : String
    , current : String
    , rate : String
    , interest : String
    , frequency : Frequency
    , currency : Currency
    , unit : String
    , targetDate : String
    , title : String
    , today : String
    , result : RemoteResult
    , saved : List SavedGoal
    , showGoals : Bool
    , notice : String
    , online : Bool
    }


type RemoteResult
    = Waiting
    | Success Calculation
    | Failure String


type alias Calculation =
    { completionDate : String
    , duration : String
    , progressPercentage : Float
    , primaryValue : Float
    , primaryLabel : String
    , secondaryValue : Maybe Float
    , secondaryLabel : Maybe String
    , milestones : List Milestone
    , scenarios : List Scenario
    , summary : String
    }


type alias Milestone =
    { amount : Float, percentage : Float, date : String }


type alias Scenario =
    { contribution : Float, completionDate : String, duration : String }


type alias SavedGoal =
    { id : String, title : String, goalType : String, payload : Decode.Value, summary : String }


type Msg
    = SelectGoal GoalType
    | ToggleReverse
    | SetTarget String
    | SetCurrent String
    | SetRate String
    | SetInterest String
    | SetFrequency String
    | SetCurrency String
    | SetUnit String
    | SetDate String
    | SetTitle String
    | GotCalculation Decode.Value
    | SaveGoal
    | Copy
    | Share
    | SharedCreated String
    | GotSharedGoal Decode.Value
    | ShowGoals
    | HideGoals
    | GotGoals Decode.Value
    | LoadGoal SavedGoal
    | NetworkChanged Bool


main : Program { today : String } Model Msg
main =
    Browser.element { init = init, update = update, subscriptions = subscriptions, view = view }


init flags =
    let
        model =
            { goalType = Savings, reverse = False, target = "20000", current = "8000", rate = "600", interest = "5", frequency = Monthly, currency = GBP, unit = "items", targetDate = "2027-12-31", title = "", today = flags.today, result = Waiting, saved = [], showGoals = False, notice = "", online = True }
    in
    recalculate model |> Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, requestLocalGoals () ])


update msg model =
    case msg of
        SelectGoal goal ->
            recalculate { model | goalType = goal, reverse = False, notice = "" }

        ToggleReverse ->
            recalculate { model | reverse = not model.reverse }

        SetTarget x ->
            recalculate { model | target = x }

        SetCurrent x ->
            recalculate { model | current = x }

        SetRate x ->
            recalculate { model | rate = x }

        SetInterest x ->
            recalculate { model | interest = x }

        SetFrequency x ->
            recalculate { model | frequency = frequencyFromString x }

        SetCurrency x ->
            ( { model | currency = currencyFromString x }, Cmd.none )

        SetUnit x ->
            recalculate { model | unit = x }

        SetDate x ->
            recalculate { model | targetDate = x }

        SetTitle x ->
            recalculate { model | title = x }

        GotCalculation raw ->
            case Decode.decodeValue responseDecoder raw of
                Ok result ->
                    ( { model | result = result }, Cmd.none )

                Err _ ->
                    ( { model | result = Failure "The calculation engine returned an unreadable result." }, Cmd.none )

        SaveGoal ->
            case model.result of
                Success result ->
                    ( { model | notice = "Saved on this device." }, saveLocalGoal (savedEncoder model result) )

                _ ->
                    ( model, Cmd.none )

        Copy ->
            case model.result of
                Success result ->
                    ( { model | notice = "Result copied." }, copyResult result.summary )

                _ ->
                    ( model, Cmd.none )

        Share ->
            case model.result of
                Success result ->
                    ( { model | notice = "Creating share link…" }, createSharedGoal (savedEncoder model result) )

                _ ->
                    ( model, Cmd.none )

        SharedCreated url ->
            ( { model
                | notice =
                    if String.isEmpty url then
                        "Sharing is unavailable; your local goal is safe."

                    else
                        "Share link copied: " ++ url
              }
            , Cmd.none
            )

        GotSharedGoal raw ->
            case Decode.decodeValue savedDecoder raw of
                Ok saved ->
                    update (LoadGoal saved) model

                Err _ ->
                    ( { model | notice = "That shared goal could not be read." }, Cmd.none )

        ShowGoals ->
            ( { model | showGoals = True }, requestLocalGoals () )

        HideGoals ->
            ( { model | showGoals = False }, Cmd.none )

        GotGoals raw ->
            ( { model | saved = Result.withDefault [] (Decode.decodeValue (Decode.list savedDecoder) raw) }, Cmd.none )

        LoadGoal saved ->
            case Decode.decodeValue savedPayloadDecoder saved.payload of
                Ok loaded ->
                    recalculate { model | goalType = goalFromString saved.goalType, title = loaded.title, target = loaded.target, current = loaded.current, rate = loaded.rate, interest = loaded.interest, unit = loaded.unit, targetDate = loaded.targetDate, frequency = frequencyFromString loaded.frequency, showGoals = False }

                Err _ ->
                    ( { model | notice = "That saved goal could not be read." }, Cmd.none )

        NetworkChanged online ->
            ( { model | online = online }, Cmd.none )


recalculate model =
    case buildRequest model of
        Ok request ->
            ( { model | result = Waiting }, calculateGoal request )

        Err message ->
            ( { model | result = Failure message }, Cmd.none )


buildRequest model =
    let
        n name raw =
            String.toFloat raw |> Result.fromMaybe ("Enter a valid " ++ name ++ ".")

        base calculator fields =
            Encode.object (( "calculator", Encode.string calculator ) :: fields)

        common target current rate =
            [ ( "target", Encode.float target ), ( "current", Encode.float current ), ( "rate", Encode.float rate ), ( "frequency", Encode.string (frequencyToString model.frequency) ), ( "startDate", Encode.string model.today ), ( "unit", Encode.string model.unit ) ]
    in
    case model.goalType of
        Countdown ->
            Ok <| base "countdown" [ ( "targetDate", Encode.string model.targetDate ), ( "startDate", Encode.string model.today ), ( "title", Encode.string model.title ) ]

        Savings ->
            Result.map3
                (\target current rate ->
                    if model.reverse then
                        base "reverseSavings" [ ( "target", Encode.float target ), ( "current", Encode.float current ), ( "targetDate", Encode.string model.targetDate ), ( "frequency", Encode.string (frequencyToString model.frequency) ), ( "startDate", Encode.string model.today ) ]

                    else
                        base "savings" [ ( "input", Encode.object [ ( "target", Encode.float target ), ( "current", Encode.float current ), ( "contribution", Encode.float rate ), ( "frequency", Encode.string (frequencyToString model.frequency) ), ( "startDate", Encode.string model.today ) ] ) ]
                )
                (n "target" model.target)
                (n "current amount" model.current)
                (n "contribution" model.rate)

        Debt ->
            Result.map3 (\balance interest payment -> base "debt" [ ( "balance", Encode.float balance ), ( "annualInterestRate", Encode.float interest ), ( "payment", Encode.float payment ), ( "frequency", Encode.string (frequencyToString model.frequency) ), ( "startDate", Encode.string model.today ) ]) (n "balance" model.target) (n "interest rate" model.interest) (n "payment" model.rate)

        ProgressGoal ->
            Result.map3 (\t c r -> base "progress" (common t c r)) (n "target" model.target) (n "completed amount" model.current) (n "rate" model.rate)

        Repetition ->
            Result.map3 (\t c r -> base "repetition" (common t c r)) (n "target" model.target) (n "completed repetitions" model.current) (n "rate" model.rate)

        Generic ->
            Result.map3 (\t c r -> base "generic" (common t c r)) (n "target" model.target) (n "current amount" model.current) (n "rate" model.rate)


subscriptions _ =
    Sub.batch [ calculationReceived GotCalculation, localGoalsReceived GotGoals, networkStatus NetworkChanged, sharedGoalCreated SharedCreated, sharedGoalReceived GotSharedGoal ]


view model =
    div [ class "page-shell" ]
        [ if model.online then
            text ""

          else
            div [ class "offline-banner", attribute "role" "status" ] [ text "Offline — calculations and saved goals still work on this device." ]
        , header [ class "site-header" ]
            [ a [ class "wordmark", href "/" ] [ span [ class "mark" ] [ text "↗" ], text "ByWhen" ]
            , div [ class "header-tools" ] [ button [ class "text-button", onClick ShowGoals ] [ text ("Your goals (" ++ String.fromInt (List.length model.saved) ++ ")") ], currencySelect model ]
            ]
        , main_ [ class "calculator" ]
            [ section [ class "intro compact-intro" ] [ p [ class "eyebrow" ] [ text "A simple goal calculator" ], h1 [] [ text "How long until…" ], p [ class "lede" ] [ text "Pick a goal. Get a clear answer." ] ]
            , goalNav model.goalType
            , if model.showGoals then
                goalsView model

              else
                calculatorView model
            ]
        , footer [] [ text "Private by default. Core calculations happen on your device." ]
        ]


goalNav current =
    div [ class "goal-tabs", attribute "aria-label" "Goal type" ] <| List.map (\( goal, label_ ) -> button [ classList [ ( "goal-tab", True ), ( "active", goal == current ) ], onClick (SelectGoal goal) ] [ text label_ ]) [ ( Savings, "Savings" ), ( Debt, "Debt" ), ( ProgressGoal, "Progress" ), ( Repetition, "Repetitions" ), ( Countdown, "Countdown" ), ( Generic, "Generic" ) ]


calculatorView model =
    section [ class "workspace" ]
        [ div [ class "form-panel" ]
            ([ div [ class "form-heading" ]
                [ h2 [] [ text (goalTitle model.goalType) ]
                , if model.goalType == Savings then
                    button [ class "mode-switch", onClick ToggleReverse ]
                        [ text
                            (if model.reverse then
                                "How long until?"

                             else
                                "What will it take?"
                            )
                        ]

                  else
                    text ""
                ]
             ]
                ++ formFields model
                ++ [ div [ class "form-actions" ] [ button [ class "primary-button", onClick SaveGoal ] [ text "Save goal" ], button [ class "secondary-button", onClick Share ] [ text "Share link" ], button [ class "secondary-button", onClick Copy ] [ text "Copy result" ] ], p [ class "notice", attribute "aria-live" "polite" ] [ text model.notice ] ]
            )
        , resultView model
        ]


formFields model =
    case model.goalType of
        Countdown ->
            [ textField "title" "What are you counting down to?" model.title SetTitle, dateField model.targetDate ]

        Debt ->
            [ numberField "target" "Current balance" model.target SetTarget, numberField "interest" "Annual interest rate (%)" model.interest SetInterest, rateField model "Regular payment" ]

        Savings ->
            [ numberField "target" "Savings target" model.target SetTarget, numberField "current" "I already have" model.current SetCurrent ]
                ++ (if model.reverse then
                        [ dateField model.targetDate, frequencyField model ]

                    else
                        [ rateField model "I add" ]
                   )

        _ ->
            [ textField "title" "Goal name (optional)" model.title SetTitle, textField "unit" "Unit (pages, hours, workouts…)" model.unit SetUnit, numberField "target" "Target" model.target SetTarget, numberField "current" "Completed so far" model.current SetCurrent, rateField model "I complete" ]


numberField id_ label_ raw msg =
    div [ class "field" ] [ label [ for id_ ] [ text label_ ], div [ class "money-input" ] [ input [ id id_, type_ "number", attribute "inputmode" "decimal", attribute "min" "0", value raw, onInput msg ] [] ] ]


textField id_ label_ raw msg =
    div [ class "field" ] [ label [ for id_ ] [ text label_ ], div [ class "money-input" ] [ input [ id id_, type_ "text", value raw, onInput msg ] [] ] ]


dateField raw =
    div [ class "field" ] [ label [ for "target-date" ] [ text "Target date" ], div [ class "money-input" ] [ input [ id "target-date", type_ "date", value raw, onInput SetDate ] [] ] ]


rateField model label_ =
    div [ class "field" ] [ label [ for "rate" ] [ text label_ ], div [ class "compound-input" ] [ input [ id "rate", type_ "number", attribute "min" "0", value model.rate, onInput SetRate ] [], frequencySelect model.frequency ], input [ class "rate-slider", type_ "range", attribute "min" "1", attribute "max" "2000", step "1", value model.rate, onInput SetRate, attribute "aria-label" (label_ ++ " slider") ] [] ]


frequencyField model =
    div [ class "field" ] [ label [ for "frequency" ] [ text "Contribution frequency" ], frequencySelect model.frequency ]


frequencySelect current =
    select [ id "frequency", attribute "aria-label" "Frequency", onInput SetFrequency ] (List.map (frequencyOption current) [ Daily, Weekly, Fortnightly, Monthly, Yearly ])


resultView model =
    section [ class "result-panel", attribute "aria-live" "polite", attribute "aria-atomic" "true" ] <|
        case model.result of
            Waiting ->
                [ div [ class "result-loading" ] [ text "Calculating…" ] ]

            Failure message ->
                [ div [ class "result-error", attribute "role" "alert" ] [ h2 [] [ text "Check your goal" ], p [] [ text message ] ] ]

            Success result ->
                [ p [ class "result-kicker" ]
                    [ text
                        (if model.reverse then
                            "You’ll need"

                         else
                            "Your answer"
                        )
                    ]
                , p [ class "duration" ]
                    [ text
                        (if model.reverse then
                            formatValue model result.primaryValue ++ " / " ++ frequencyLabel model.frequency

                         else
                            result.duration
                        )
                    ]
                , p [ class "completion-label" ]
                    [ text
                        (if model.goalType == Countdown then
                            result.primaryLabel

                         else
                            "Estimated completion"
                        )
                    ]
                , p [ class "completion-date" ]
                    [ text
                        (if model.goalType == Countdown then
                            String.fromInt (round result.primaryValue) ++ " days"

                         else
                            friendlyDate result.completionDate
                        )
                    ]
                , if result.progressPercentage > 0 then
                    div [ class "progress-block" ] [ progress [ attribute "max" "100", value (String.fromFloat result.progressPercentage) ] [], p [ class "percentage" ] [ text (String.fromInt (round result.progressPercentage) ++ "% complete") ] ]

                  else
                    text ""
                , if model.goalType == Debt then
                    div [ class "result-stat" ] [ span [] [ text result.primaryLabel ], strongText (formatValue model result.primaryValue) ]

                  else
                    text ""
                , case ( result.secondaryValue, result.secondaryLabel ) of
                    ( Just value_, Just label_ ) ->
                        div [ class "result-stat" ] [ span [] [ text label_ ], strongText (formatValue model value_) ]

                    _ ->
                        text ""
                , supporting model result
                ]


supporting model result =
    div [ class "supporting" ]
        [ if List.isEmpty result.milestones then
            text ""

          else
            section [ class "detail-section" ] [ h2 [] [ text "Milestones" ], div [] (List.map (\m -> div [ class "detail-row" ] [ span [] [ text (formatValue model m.amount) ], span [] [ text (friendlyDate m.date) ] ]) result.milestones) ]
        , if List.isEmpty result.scenarios then
            text ""

          else
            section [ class "detail-section" ] [ h2 [] [ text "What if you changed the pace?" ], div [] (List.map (\s -> div [ class "detail-row" ] [ span [] [ text (formatValue model s.contribution ++ " / " ++ frequencyLabel model.frequency) ], span [] [ text (friendlyDate s.completionDate) ] ]) result.scenarios) ]
        ]


goalsView model =
    section [ class "saved-panel" ]
        [ div [ class "saved-heading" ] [ h2 [] [ text "Your goals" ], button [ class "secondary-button", onClick HideGoals ] [ text "Back to calculator" ] ]
        , if List.isEmpty model.saved then
            p [ class "empty-state" ] [ text "No saved goals yet. Save one from any calculator." ]

          else
            div [ class "saved-grid" ] (List.map savedCard model.saved)
        ]


savedCard saved =
    button [ class "saved-card", onClick (LoadGoal saved) ] [ span [ class "saved-kind" ] [ text saved.goalType ], h2 [] [ text saved.title ], p [] [ text saved.summary ] ]


responseDecoder =
    Decode.field "ok" Decode.bool
        |> Decode.andThen
            (\ok ->
                if ok then
                    Decode.map Success (Decode.field "result" calculationDecoder)

                else
                    Decode.map Failure (Decode.field "error" Decode.string)
            )


calculationDecoder =
    Decode.map8 (\date duration progress_ primary label_ secondary secondaryLabel summary -> { completionDate = date, duration = duration, progressPercentage = progress_, primaryValue = primary, primaryLabel = label_, secondaryValue = secondary, secondaryLabel = secondaryLabel, milestones = [], scenarios = [], summary = summary }) (Decode.field "completionDate" Decode.string) (Decode.field "duration" Decode.string) (Decode.field "progressPercentage" Decode.float) (Decode.field "primaryValue" Decode.float) (Decode.field "primaryLabel" Decode.string) (Decode.field "secondaryValue" (Decode.nullable Decode.float)) (Decode.field "secondaryLabel" (Decode.nullable Decode.string)) (Decode.field "summary" Decode.string) |> Decode.andThen (\partial -> Decode.map2 (\ms ss -> { partial | milestones = ms, scenarios = ss }) (Decode.field "milestones" (Decode.list milestoneDecoder)) (Decode.field "scenarios" (Decode.list scenarioDecoder)))


milestoneDecoder =
    Decode.map3 Milestone (Decode.field "amount" Decode.float) (Decode.field "percentage" Decode.float) (Decode.field "date" Decode.string)


scenarioDecoder =
    Decode.map3 Scenario (Decode.field "contribution" Decode.float) (Decode.field "completionDate" Decode.string) (Decode.field "duration" Decode.string)


savedEncoder model result =
    Encode.object
        [ ( "id", Encode.string (model.today ++ "-" ++ goalToString model.goalType ++ "-" ++ model.title) )
        , ( "title"
          , Encode.string
                (if String.isEmpty model.title then
                    goalTitle model.goalType

                 else
                    model.title
                )
          )
        , ( "goalType", Encode.string (goalToString model.goalType) )
        , ( "summary", Encode.string result.summary )
        , ( "payload", Encode.object [ ( "title", Encode.string model.title ), ( "target", Encode.string model.target ), ( "current", Encode.string model.current ), ( "rate", Encode.string model.rate ), ( "interest", Encode.string model.interest ), ( "unit", Encode.string model.unit ), ( "targetDate", Encode.string model.targetDate ), ( "frequency", Encode.string (frequencyToString model.frequency) ) ] )
        ]


savedDecoder =
    Decode.map5 SavedGoal (Decode.field "id" Decode.string) (Decode.field "title" Decode.string) (Decode.field "goalType" Decode.string) (Decode.field "payload" Decode.value) (Decode.field "summary" Decode.string)


type alias SavedPayload =
    { title : String, target : String, current : String, rate : String, interest : String, unit : String, targetDate : String, frequency : String }


savedPayloadDecoder =
    Decode.map8 SavedPayload (Decode.field "title" Decode.string) (Decode.field "target" Decode.string) (Decode.field "current" Decode.string) (Decode.field "rate" Decode.string) (Decode.field "interest" Decode.string) (Decode.field "unit" Decode.string) (Decode.field "targetDate" Decode.string) (Decode.field "frequency" Decode.string)


currencySelect model =
    select [ id "currency", class "currency-select", onInput SetCurrency ] [ option [ value "GBP", selected (model.currency == GBP) ] [ text "£ GBP" ], option [ value "USD", selected (model.currency == USD) ] [ text "$ USD" ], option [ value "EUR", selected (model.currency == EUR) ] [ text "€ EUR" ] ]


frequencyOption current f =
    option [ value (frequencyToString f), selected (current == f) ] [ text (frequencyLabel f) ]


frequencyToString f =
    case f of
        Daily ->
            "daily"

        Weekly ->
            "weekly"

        Fortnightly ->
            "fortnightly"

        Monthly ->
            "monthly"

        Yearly ->
            "yearly"


frequencyLabel f =
    case f of
        Daily ->
            "day"

        Weekly ->
            "week"

        Fortnightly ->
            "fortnight"

        Monthly ->
            "month"

        Yearly ->
            "year"


frequencyFromString x =
    case x of
        "daily" ->
            Daily

        "weekly" ->
            Weekly

        "fortnightly" ->
            Fortnightly

        "yearly" ->
            Yearly

        _ ->
            Monthly


currencyFromString x =
    case x of
        "USD" ->
            USD

        "EUR" ->
            EUR

        _ ->
            GBP


goalTitle g =
    case g of
        Savings ->
            "Savings"

        Debt ->
            "Debt payoff"

        ProgressGoal ->
            "Progress"

        Repetition ->
            "Repetitions"

        Countdown ->
            "Countdown"

        Generic ->
            "Generic goal"


goalToString g =
    case g of
        Savings ->
            "savings"

        Debt ->
            "debt"

        ProgressGoal ->
            "progress"

        Repetition ->
            "repetition"

        Countdown ->
            "countdown"

        Generic ->
            "generic"


goalFromString x =
    case x of
        "debt" ->
            Debt

        "progress" ->
            ProgressGoal

        "repetition" ->
            Repetition

        "countdown" ->
            Countdown

        "generic" ->
            Generic

        _ ->
            Savings


formatValue model amount =
    if model.goalType == Savings || model.goalType == Debt then
        currencySymbol model.currency ++ formatInteger (round amount)

    else
        String.fromInt (round amount) ++ " " ++ model.unit


currencySymbol c =
    case c of
        GBP ->
            "£"

        USD ->
            "$"

        EUR ->
            "€"


formatInteger number =
    let
        digits =
            String.fromInt number

        add s =
            if String.length s <= 3 then
                s

            else
                add (String.dropRight 3 s) ++ "," ++ String.right 3 s
    in
    add digits


friendlyDate iso =
    case String.split "-" iso of
        [ y, m, d ] ->
            String.fromInt (Maybe.withDefault 0 (String.toInt d)) ++ " " ++ monthName m ++ " " ++ y

        _ ->
            iso


monthName m =
    case m of
        "01" ->
            "January"

        "02" ->
            "February"

        "03" ->
            "March"

        "04" ->
            "April"

        "05" ->
            "May"

        "06" ->
            "June"

        "07" ->
            "July"

        "08" ->
            "August"

        "09" ->
            "September"

        "10" ->
            "October"

        "11" ->
            "November"

        "12" ->
            "December"

        _ ->
            ""


strongText value_ =
    Html.strong [] [ text value_ ]
