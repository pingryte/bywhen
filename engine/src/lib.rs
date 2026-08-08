mod calculators;
mod models;
mod validation;

pub use calculators::savings::calculate as calculate_savings;
pub use calculators::universal::calculate as calculate_goal;
pub use models::*;
pub use validation::CalculationError;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn calculate_savings_json(request: &str) -> String {
    let response = serde_json::from_str::<SavingsInput>(request)
        .map_err(|error| CalculationError::InvalidRequest(error.to_string()))
        .and_then(|input| calculate_savings(&input));
    match response {
        Ok(result) => serde_json::json!({ "ok": true, "result": result }).to_string(),
        Err(error) => serde_json::json!({ "ok": false, "error": error.to_string() }).to_string(),
    }
}

#[wasm_bindgen]
pub fn calculate_goal_json(request: &str) -> String {
    let response = serde_json::from_str::<GoalInput>(request)
        .map_err(|error| CalculationError::InvalidRequest(error.to_string()))
        .and_then(calculate_goal);
    match response {
        Ok(result) => serde_json::json!({ "ok": true, "result": result }).to_string(),
        Err(error) => serde_json::json!({ "ok": false, "error": error.to_string() }).to_string(),
    }
}
