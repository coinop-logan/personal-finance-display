use elm_rs::{Elm, ElmDecode, ElmEncode};
use serde::{Deserialize, Serialize};

/// A single finance entry
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct Entry {
    pub id: i32,
    pub date: String,
    pub checking: f64,
    pub credit_available: f64,
    pub hours_worked: f64,
    pub pay_per_hour: f64,
    pub other_incoming: f64,
    pub personal_debt: f64,
    pub note: String,
}

/// Request body for creating a new entry
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmDecode, ElmEncode)]
#[serde(rename_all = "camelCase")]
pub struct NewEntry {
    pub date: String,
    pub checking: f64,
    pub credit_available: f64,
    pub hours_worked: f64,
    pub pay_per_hour: f64,
    pub other_incoming: f64,
    pub personal_debt: f64,
    pub note: String,
}

/// Generic API response for mutations
#[derive(Debug, Clone, Serialize, Deserialize, Elm, ElmEncode)]
pub struct ApiResponse {
    pub ok: bool,
}
