use chrono::{Datelike, NaiveDate};

use crate::calculators::savings::{add_periods, calculate as calculate_savings};
use crate::models::{Frequency, GoalInput, Milestone, SavingsInput, UniversalResult};
use crate::validation::CalculationError;

pub fn calculate(input: GoalInput) -> Result<UniversalResult, CalculationError> {
    match input {
        GoalInput::Savings { input } => savings(input),
        GoalInput::ReverseSavings {
            target,
            current,
            target_date,
            frequency,
            start_date,
        } => reverse(target, current, target_date, frequency, start_date),
        GoalInput::Debt {
            balance,
            annual_interest_rate,
            payment,
            frequency,
            start_date,
        } => debt(
            balance,
            annual_interest_rate,
            payment,
            frequency,
            start_date,
        ),
        GoalInput::Generic {
            target,
            current,
            rate,
            frequency,
            start_date,
            unit,
        }
        | GoalInput::Progress {
            target,
            current,
            rate,
            frequency,
            start_date,
            unit,
        }
        | GoalInput::Repetition {
            target,
            current,
            rate,
            frequency,
            start_date,
            unit,
        } => rate_goal(target, current, rate, frequency, start_date, unit),
        GoalInput::Countdown {
            target_date,
            start_date,
            title,
        } => countdown(target_date, start_date, title),
    }
}

fn savings(input: SavingsInput) -> Result<UniversalResult, CalculationError> {
    let current = input.current;
    let target = input.target;
    let contribution = input.contribution;
    let result = calculate_savings(&input)?;
    Ok(UniversalResult {
        duration: result.duration.human,
        completion_date: result.completion_date,
        progress_percentage: result.progress_percentage,
        primary_value: target - current,
        primary_label: "left to save".into(),
        secondary_value: None,
        secondary_label: None,
        milestones: result.milestones,
        scenarios: result.scenarios,
        summary: format!(
            "At {contribution:.0} per period, you’ll reach {target:.0} on {}.",
            result.completion_date
        ),
    })
}

fn rate_goal(
    target: f64,
    current: f64,
    rate: f64,
    frequency: Frequency,
    start: NaiveDate,
    unit: String,
) -> Result<UniversalResult, CalculationError> {
    validate_rate(target, current, rate)?;
    let periods = ((target - current) / rate).ceil() as u64;
    let completion = add_periods(start, periods, frequency)?;
    let duration = human_between(start, completion, periods, frequency);
    let milestones = [0.25, 0.5, 0.75, 1.0]
        .into_iter()
        .filter_map(|p| {
            let amount = target * p;
            if amount <= current {
                return None;
            }
            let count = ((amount - current) / rate).ceil() as u64;
            add_periods(start, count, frequency)
                .ok()
                .map(|date| Milestone {
                    amount,
                    percentage: p * 100.0,
                    date,
                })
        })
        .collect();
    Ok(UniversalResult {
        duration: duration.clone(),
        completion_date: completion,
        progress_percentage: current / target * 100.0,
        primary_value: target - current,
        primary_label: format!("{unit} remaining"),
        secondary_value: None,
        secondary_label: None,
        milestones,
        scenarios: vec![],
        summary: format!("At {rate:.0} {unit} per period, you’ll finish in {duration}."),
    })
}

fn debt(
    balance: f64,
    annual_rate: f64,
    payment: f64,
    frequency: Frequency,
    start: NaiveDate,
) -> Result<UniversalResult, CalculationError> {
    if balance <= 0.0 {
        return Err(CalculationError::InvalidTarget);
    }
    if payment <= 0.0 {
        return Err(CalculationError::InvalidContribution);
    }
    if annual_rate < 0.0 || !annual_rate.is_finite() {
        return Err(CalculationError::InvalidRequest(
            "Interest rate cannot be negative.".into(),
        ));
    }
    let per_year = periods_per_year(frequency);
    let period_rate = annual_rate / 100.0 / per_year;
    if payment <= balance * period_rate {
        return Err(CalculationError::ImpossibleDebt);
    }
    let original = balance;
    let mut remaining = balance;
    let mut interest_paid = 0.0;
    let mut periods = 0u64;
    while remaining > 0.005 && periods < 1_000_000 {
        let interest = remaining * period_rate;
        interest_paid += interest;
        remaining = (remaining + interest - payment).max(0.0);
        periods += 1;
    }
    if periods >= 1_000_000 {
        return Err(CalculationError::OutOfRange);
    }
    let completion = add_periods(start, periods, frequency)?;
    let duration = human_between(start, completion, periods, frequency);
    Ok(UniversalResult { duration: duration.clone(), completion_date: completion, progress_percentage: 0.0,
        primary_value: interest_paid, primary_label: "estimated interest".into(), secondary_value: Some(original + interest_paid), secondary_label: Some("total paid".into()),
        milestones: vec![], scenarios: vec![], summary: format!("This debt should be paid off in {duration}, with about {interest_paid:.2} in interest.") })
}

fn reverse(
    target: f64,
    current: f64,
    target_date: NaiveDate,
    frequency: Frequency,
    start: NaiveDate,
) -> Result<UniversalResult, CalculationError> {
    if target <= current {
        return Err(CalculationError::TargetAlreadyReached);
    }
    if target_date <= start {
        return Err(CalculationError::InvalidRequest(
            "Choose a target date in the future.".into(),
        ));
    }
    let periods = count_periods(start, target_date, frequency).max(1);
    let required = (target - current) / periods as f64;
    Ok(UniversalResult {
        duration: human_between(start, target_date, periods, frequency),
        completion_date: target_date,
        progress_percentage: current / target * 100.0,
        primary_value: required,
        primary_label: "required each period".into(),
        secondary_value: None,
        secondary_label: None,
        milestones: vec![],
        scenarios: vec![],
        summary: format!("Save {required:.2} each period to reach {target:.0} by {target_date}."),
    })
}

fn countdown(
    target: NaiveDate,
    start: NaiveDate,
    title: String,
) -> Result<UniversalResult, CalculationError> {
    let days = (target - start).num_days();
    let duration = if days < 0 {
        format!("{} days ago", -days)
    } else if days == 0 {
        "Today".into()
    } else {
        format!("{} weeks, {} days", days / 7, days % 7)
    };
    Ok(UniversalResult {
        duration: duration.clone(),
        completion_date: target,
        progress_percentage: 0.0,
        primary_value: days.unsigned_abs() as f64,
        primary_label: if days < 0 {
            "days since".into()
        } else {
            "days remaining".into()
        },
        secondary_value: None,
        secondary_label: None,
        milestones: vec![],
        scenarios: vec![],
        summary: if title.is_empty() {
            format!("{duration} until {target}.")
        } else {
            format!("{duration} until {title}.")
        },
    })
}

fn validate_rate(target: f64, current: f64, rate: f64) -> Result<(), CalculationError> {
    if target <= 0.0 || !target.is_finite() {
        return Err(CalculationError::InvalidTarget);
    }
    if current < 0.0 || !current.is_finite() {
        return Err(CalculationError::NegativeCurrent);
    }
    if current >= target {
        return Err(CalculationError::TargetAlreadyReached);
    }
    if rate <= 0.0 || !rate.is_finite() {
        return Err(CalculationError::InvalidContribution);
    }
    Ok(())
}

fn periods_per_year(frequency: Frequency) -> f64 {
    match frequency {
        Frequency::Daily => 365.0,
        Frequency::Weekly => 52.0,
        Frequency::Fortnightly => 26.0,
        Frequency::Monthly => 12.0,
        Frequency::Yearly => 1.0,
    }
}

fn count_periods(start: NaiveDate, end: NaiveDate, frequency: Frequency) -> u64 {
    let days = (end - start).num_days().max(1) as f64;
    match frequency {
        Frequency::Daily => days.floor() as u64,
        Frequency::Weekly => (days / 7.0).floor() as u64,
        Frequency::Fortnightly => (days / 14.0).floor() as u64,
        Frequency::Monthly => ((end.year() - start.year()) * 12 + end.month() as i32
            - start.month() as i32)
            .max(1) as u64,
        Frequency::Yearly => (end.year() - start.year()).max(1) as u64,
    }
}

fn human_between(start: NaiveDate, end: NaiveDate, periods: u64, frequency: Frequency) -> String {
    match frequency {
        Frequency::Monthly => {
            let y = periods / 12;
            let m = periods % 12;
            match (y, m) {
                (0, m) => format!("{m} month{}", if m == 1 { "" } else { "s" }),
                (y, 0) => format!("{y} year{}", if y == 1 { "" } else { "s" }),
                _ => format!(
                    "{y} year{}, {m} month{}",
                    if y == 1 { "" } else { "s" },
                    if m == 1 { "" } else { "s" }
                ),
            }
        }
        Frequency::Yearly => format!("{periods} year{}", if periods == 1 { "" } else { "s" }),
        _ => {
            let days = (end - start).num_days();
            format!("{} weeks, {} days", days / 7, days % 7)
        }
    }
}
