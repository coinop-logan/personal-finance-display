use elm_rs::{Elm, ElmDecode, ElmEncode};
use serde::{Deserialize, Serialize};

/// A job type (template for work logs)
/// Jobs are hardcoded, not user-editable
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct Job {
    pub id: String,
    pub name: String,
}

/// A work log entry - hours worked for a specific job on a specific date
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct WorkLog {
    pub id: i32,
    pub date: String,
    pub job_id: String,
    pub hours: f64,
    pub pay_rate: f64,
    pub tax_rate: f64,
    pub pay_cashed: bool,
}

/// Request body for creating a new work log
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct NewWorkLog {
    pub date: String,
    pub job_id: String,
    pub hours: f64,
    pub pay_rate: f64,
    pub tax_rate: f64,
    pub pay_cashed: bool,
}

/// A balance snapshot - financial state on a specific date
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct BalanceSnapshot {
    pub id: i32,
    pub date: String,
    pub checking: f64,
    pub credit_available: f64,
    pub credit_limit: f64,
    pub personal_debt: f64,
    pub note: String,
}

/// Request body for creating a new balance snapshot
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct NewBalanceSnapshot {
    pub date: String,
    pub checking: f64,
    pub credit_available: f64,
    pub credit_limit: f64,
    pub personal_debt: f64,
    pub note: String,
}

/// All finance data bundled together for API responses
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct FinanceData {
    pub jobs: Vec<Job>,
    pub work_logs: Vec<WorkLog>,
    pub balance_snapshots: Vec<BalanceSnapshot>,
}

/// Generic API response for mutations
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmEncode)]
pub struct ApiResponse {
    pub ok: bool,
}

/// Weather data for Anchorage
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct Weather {
    pub current_f: i32,
    pub high_f: i32,
    pub low_f: i32,
}

/// A single forecast period from NWS
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct ForecastPeriod {
    pub name: String,
    pub temperature: i32,
    pub temperature_unit: String,
    pub wind_speed: String,
    pub wind_direction: String,
    pub short_forecast: String,
    pub detailed_forecast: String,
    pub precipitation_chance: Option<i32>,
    pub is_daytime: bool,
}

/// A weather alert from NWS
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct WeatherAlert {
    pub event: String,
    pub severity: String,
    pub headline: String,
    pub description: String,
    pub instruction: Option<String>,
    pub areas: String,
    pub ends: Option<String>,
}

/// Full weather briefing data for LLM consumption
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct WeatherBriefing {
    pub generated_at: String,
    pub alerts: Vec<WeatherAlert>,
    pub forecast_periods: Vec<ForecastPeriod>,
}
