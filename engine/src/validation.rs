use thiserror::Error;

#[derive(Debug, Error, PartialEq)]
pub enum CalculationError {
    #[error("Target must be greater than zero.")]
    InvalidTarget,
    #[error("Current amount cannot be negative.")]
    NegativeCurrent,
    #[error("Enter a contribution greater than zero.")]
    InvalidContribution,
    #[error("Your target is already reached.")]
    TargetAlreadyReached,
    #[error("The result is too far in the future to calculate safely.")]
    OutOfRange,
    #[error("The calculation request could not be read: {0}")]
    InvalidRequest(String),
    #[error("Your payment is lower than the interest being added, so this debt will not currently be paid off.")]
    ImpossibleDebt,
}
