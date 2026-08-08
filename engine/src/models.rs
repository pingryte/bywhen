use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Frequency {
    Daily,
    Weekly,
    Fortnightly,
    Monthly,
    Yearly,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SavingsInput {
    pub target: f64,
    pub current: f64,
    pub contribution: f64,
    pub frequency: Frequency,
    pub start_date: NaiveDate,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DurationEstimate {
    pub periods: u64,
    pub years: u32,
    pub months: u32,
    pub weeks: u32,
    pub days: u32,
    pub human: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Milestone {
    pub amount: f64,
    pub percentage: f64,
    pub date: NaiveDate,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Scenario {
    pub contribution: f64,
    pub completion_date: NaiveDate,
    pub duration: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CalculationResult {
    pub completion_date: NaiveDate,
    pub duration: DurationEstimate,
    pub progress_percentage: f64,
    pub milestones: Vec<Milestone>,
    pub scenarios: Vec<Scenario>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    tag = "calculator",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum GoalInput {
    Savings {
        input: SavingsInput,
    },
    ReverseSavings {
        target: f64,
        current: f64,
        target_date: NaiveDate,
        frequency: Frequency,
        start_date: NaiveDate,
    },
    Debt {
        balance: f64,
        annual_interest_rate: f64,
        payment: f64,
        frequency: Frequency,
        start_date: NaiveDate,
    },
    Generic {
        target: f64,
        current: f64,
        rate: f64,
        frequency: Frequency,
        start_date: NaiveDate,
        unit: String,
    },
    Progress {
        target: f64,
        current: f64,
        rate: f64,
        frequency: Frequency,
        start_date: NaiveDate,
        unit: String,
    },
    Repetition {
        target: f64,
        current: f64,
        rate: f64,
        frequency: Frequency,
        start_date: NaiveDate,
        unit: String,
    },
    Countdown {
        target_date: NaiveDate,
        start_date: NaiveDate,
        title: String,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UniversalResult {
    pub duration: String,
    pub completion_date: NaiveDate,
    pub progress_percentage: f64,
    pub primary_value: f64,
    pub primary_label: String,
    pub secondary_value: Option<f64>,
    pub secondary_label: Option<String>,
    pub milestones: Vec<Milestone>,
    pub scenarios: Vec<Scenario>,
    pub summary: String,
}
