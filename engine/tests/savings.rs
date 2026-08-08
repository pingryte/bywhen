use bywhen_engine::{calculate_savings, Frequency, SavingsInput};
use chrono::NaiveDate;
use proptest::prelude::*;

fn input(current: f64, contribution: f64) -> SavingsInput {
    SavingsInput {
        target: 20_000.0,
        current,
        contribution,
        frequency: Frequency::Monthly,
        start_date: NaiveDate::from_ymd_opt(2026, 8, 8).unwrap(),
    }
}

#[test]
fn example_takes_twenty_months() {
    let result = calculate_savings(&input(8_000.0, 600.0)).unwrap();
    assert_eq!(result.duration.months, 8);
    assert_eq!(result.duration.years, 1);
    assert_eq!(
        result.completion_date,
        NaiveDate::from_ymd_opt(2028, 4, 8).unwrap()
    );
    assert_eq!(result.progress_percentage, 40.0);
}

#[test]
fn clamps_calendar_months_at_month_end() {
    let value = SavingsInput {
        target: 2.0,
        current: 0.0,
        contribution: 1.0,
        frequency: Frequency::Monthly,
        start_date: NaiveDate::from_ymd_opt(2024, 12, 31).unwrap(),
    };
    assert_eq!(
        calculate_savings(&value).unwrap().completion_date,
        NaiveDate::from_ymd_opt(2025, 2, 28).unwrap()
    );
}

#[test]
fn rejects_zero_contribution() {
    assert!(calculate_savings(&input(8_000.0, 0.0)).is_err());
}

proptest! {
    #[test]
    fn a_higher_rate_never_finishes_later(rate in 1.0f64..10_000.0, extra in 0.0f64..10_000.0) {
        let first = calculate_savings(&input(1_000.0, rate)).unwrap().completion_date;
        let second = calculate_savings(&input(1_000.0, rate + extra)).unwrap().completion_date;
        prop_assert!(second <= first);
    }
}
