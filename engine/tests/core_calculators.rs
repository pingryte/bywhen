use bywhen_engine::{calculate_goal, Frequency, GoalInput};
use chrono::NaiveDate;

fn start() -> NaiveDate {
    NaiveDate::from_ymd_opt(2026, 8, 8).unwrap()
}

#[test]
fn generic_goal_uses_units_and_calendar_months() {
    let result = calculate_goal(GoalInput::Generic {
        target: 500.0,
        current: 120.0,
        rate: 8.0,
        frequency: Frequency::Weekly,
        start_date: start(),
        unit: "pages".into(),
    })
    .unwrap();
    assert_eq!(result.primary_value, 380.0);
    assert_eq!(
        result.completion_date,
        NaiveDate::from_ymd_opt(2027, 7, 10).unwrap()
    );
}

#[test]
fn debt_rejects_a_payment_below_interest() {
    let result = calculate_goal(GoalInput::Debt {
        balance: 8_000.0,
        annual_interest_rate: 24.0,
        payment: 100.0,
        frequency: Frequency::Monthly,
        start_date: start(),
    });
    assert!(result.is_err());
}

#[test]
fn reverse_savings_returns_required_rate() {
    let result = calculate_goal(GoalInput::ReverseSavings {
        target: 20_000.0,
        current: 8_000.0,
        target_date: NaiveDate::from_ymd_opt(2027, 8, 8).unwrap(),
        frequency: Frequency::Monthly,
        start_date: start(),
    })
    .unwrap();
    assert_eq!(result.primary_value, 1_000.0);
}

#[test]
fn countdown_handles_past_dates() {
    let result = calculate_goal(GoalInput::Countdown {
        target_date: NaiveDate::from_ymd_opt(2026, 8, 1).unwrap(),
        start_date: start(),
        title: "Launch".into(),
    })
    .unwrap();
    assert_eq!(result.duration, "7 days ago");
}
