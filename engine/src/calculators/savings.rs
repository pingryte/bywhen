use chrono::{Datelike, Duration, NaiveDate};

use crate::models::{
    CalculationResult, DurationEstimate, Frequency, Milestone, SavingsInput, Scenario,
};
use crate::validation::CalculationError;

const MAX_PERIODS: u64 = 1_000_000;

pub fn calculate(input: &SavingsInput) -> Result<CalculationResult, CalculationError> {
    validate(input)?;
    let remaining = input.target - input.current;
    let periods = (remaining / input.contribution).ceil() as u64;
    if periods > MAX_PERIODS {
        return Err(CalculationError::OutOfRange);
    }
    let completion_date = add_periods(input.start_date, periods, input.frequency)?;

    Ok(CalculationResult {
        completion_date,
        duration: duration_estimate(input.start_date, completion_date, periods, input.frequency),
        progress_percentage: (input.current / input.target * 100.0).clamp(0.0, 100.0),
        milestones: milestones(input)?,
        scenarios: scenarios(input)?,
        warnings: Vec::new(),
    })
}

fn validate(input: &SavingsInput) -> Result<(), CalculationError> {
    if !input.target.is_finite() || input.target <= 0.0 {
        return Err(CalculationError::InvalidTarget);
    }
    if !input.current.is_finite() || input.current < 0.0 {
        return Err(CalculationError::NegativeCurrent);
    }
    if !input.contribution.is_finite() || input.contribution <= 0.0 {
        return Err(CalculationError::InvalidContribution);
    }
    if input.current >= input.target {
        return Err(CalculationError::TargetAlreadyReached);
    }
    Ok(())
}

fn milestones(input: &SavingsInput) -> Result<Vec<Milestone>, CalculationError> {
    [0.25, 0.5, 0.75, 1.0]
        .into_iter()
        .filter_map(|percentage| {
            let amount = input.target * percentage;
            if amount <= input.current {
                return None;
            }
            let periods = ((amount - input.current) / input.contribution).ceil() as u64;
            Some(
                add_periods(input.start_date, periods, input.frequency).map(|date| Milestone {
                    amount,
                    percentage: percentage * 100.0,
                    date,
                }),
            )
        })
        .collect()
}

fn scenarios(input: &SavingsInput) -> Result<Vec<Scenario>, CalculationError> {
    [0.75, 1.0, 1.25, 1.5]
        .into_iter()
        .map(|factor| {
            let contribution = input.contribution * factor;
            let periods = ((input.target - input.current) / contribution).ceil() as u64;
            let date = add_periods(input.start_date, periods, input.frequency)?;
            Ok(Scenario {
                contribution,
                completion_date: date,
                duration: duration_estimate(input.start_date, date, periods, input.frequency).human,
            })
        })
        .collect()
}

pub fn add_periods(
    date: NaiveDate,
    periods: u64,
    frequency: Frequency,
) -> Result<NaiveDate, CalculationError> {
    match frequency {
        Frequency::Daily => date.checked_add_signed(Duration::days(periods as i64)),
        Frequency::Weekly => date.checked_add_signed(Duration::weeks(periods as i64)),
        Frequency::Fortnightly => date.checked_add_signed(Duration::weeks((periods * 2) as i64)),
        Frequency::Monthly => add_months_clamped(date, periods),
        Frequency::Yearly => add_months_clamped(date, periods * 12),
    }
    .ok_or(CalculationError::OutOfRange)
}

fn add_months_clamped(date: NaiveDate, months: u64) -> Option<NaiveDate> {
    let total = date.year() as i64 * 12 + date.month0() as i64 + months as i64;
    let year = i32::try_from(total.div_euclid(12)).ok()?;
    let month = total.rem_euclid(12) as u32 + 1;
    let last_day = (28..=31)
        .rev()
        .find(|day| NaiveDate::from_ymd_opt(year, month, *day).is_some())?;
    NaiveDate::from_ymd_opt(year, month, date.day().min(last_day))
}

fn duration_estimate(
    start: NaiveDate,
    end: NaiveDate,
    periods: u64,
    frequency: Frequency,
) -> DurationEstimate {
    let total_days = (end - start).num_days().max(0) as u32;
    let (years, months, weeks, days) = match frequency {
        Frequency::Monthly => ((periods / 12) as u32, (periods % 12) as u32, 0, 0),
        Frequency::Yearly => (periods as u32, 0, 0, 0),
        _ => (0, 0, total_days / 7, total_days % 7),
    };
    let mut parts = Vec::new();
    for (value, singular) in [
        (years, "year"),
        (months, "month"),
        (weeks, "week"),
        (days, "day"),
    ] {
        if value > 0 {
            parts.push(format!(
                "{value} {singular}{}",
                if value == 1 { "" } else { "s" }
            ));
        }
    }
    DurationEstimate {
        periods,
        years,
        months,
        weeks,
        days,
        human: if parts.is_empty() {
            "Today".into()
        } else {
            parts.join(", ")
        },
    }
}
