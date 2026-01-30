mod types;

use axum::{
    extract::{Path, State},
    http::{header, HeaderValue, StatusCode},
    routing::{delete, get, post},
    Json, Router,
};
use std::sync::{Arc, RwLock};
use std::{fs, path::PathBuf};
use tower_http::services::{ServeDir, ServeFile};
use tower_http::set_header::SetResponseHeaderLayer;
use types::{ApiResponse, BalanceSnapshot, FinanceData, ForecastPeriod, Job, NewBalanceSnapshot, NewWorkLog, Weather, WeatherAlert, WeatherBriefing, WorkLog};

type AppState = Arc<RwLock<AppData>>;

struct AppData {
    jobs: Vec<Job>,
    work_logs: Vec<WorkLog>,
    balance_snapshots: Vec<BalanceSnapshot>,
    next_work_log_id: i32,
    next_snapshot_id: i32,
    data_file: PathBuf,
}

impl AppData {
    fn load(data_file: PathBuf) -> Self {
        let (work_logs, balance_snapshots): (Vec<WorkLog>, Vec<BalanceSnapshot>) = if data_file.exists() {
            let content = fs::read_to_string(&data_file).unwrap_or_default();
            if let Ok(data) = serde_json::from_str::<FinanceData>(&content) {
                (data.work_logs, data.balance_snapshots)
            } else {
                (Vec::new(), Vec::new())
            }
        } else {
            (Vec::new(), Vec::new())
        };

        let next_work_log_id = work_logs.iter().map(|w| w.id).max().unwrap_or(0) + 1;
        let next_snapshot_id = balance_snapshots.iter().map(|s| s.id).max().unwrap_or(0) + 1;

        // Hardcoded jobs
        let jobs = vec![
            Job { id: "alborn".to_string(), name: "Alborn".to_string() },
            Job { id: "museum".to_string(), name: "Museum".to_string() },
        ];

        Self {
            jobs,
            work_logs,
            balance_snapshots,
            next_work_log_id,
            next_snapshot_id,
            data_file,
        }
    }

    fn save(&self) {
        let data = FinanceData {
            jobs: self.jobs.clone(),
            work_logs: self.work_logs.clone(),
            balance_snapshots: self.balance_snapshots.clone(),
        };
        let content = serde_json::to_string_pretty(&data).unwrap();
        fs::write(&self.data_file, content).ok();
    }
}

async fn get_data(State(state): State<AppState>) -> Json<FinanceData> {
    let data = state.read().unwrap();
    Json(FinanceData {
        jobs: data.jobs.clone(),
        work_logs: data.work_logs.clone(),
        balance_snapshots: data.balance_snapshots.clone(),
    })
}

async fn create_work_log(
    State(state): State<AppState>,
    Json(new_log): Json<NewWorkLog>,
) -> (StatusCode, Json<ApiResponse>) {
    let mut data = state.write().unwrap();

    let log = WorkLog {
        id: data.next_work_log_id,
        date: new_log.date,
        job_id: new_log.job_id,
        hours: new_log.hours,
        pay_rate: new_log.pay_rate,
        tax_rate: new_log.tax_rate,
        pay_cashed: new_log.pay_cashed,
    };

    data.next_work_log_id += 1;
    data.work_logs.push(log);
    data.work_logs.sort_by(|a, b| a.date.cmp(&b.date));

    data.save();
    (StatusCode::OK, Json(ApiResponse { ok: true }))
}

async fn delete_work_log(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> (StatusCode, Json<ApiResponse>) {
    let mut data = state.write().unwrap();

    let original_len = data.work_logs.len();
    data.work_logs.retain(|w| w.id != id);

    if data.work_logs.len() == original_len {
        return (StatusCode::NOT_FOUND, Json(ApiResponse { ok: false }));
    }

    data.save();
    (StatusCode::OK, Json(ApiResponse { ok: true }))
}

async fn create_balance_snapshot(
    State(state): State<AppState>,
    Json(new_snapshot): Json<NewBalanceSnapshot>,
) -> (StatusCode, Json<ApiResponse>) {
    let mut data = state.write().unwrap();

    // Check if snapshot for this date already exists - if so, overwrite it
    if let Some(existing) = data.balance_snapshots.iter_mut().find(|s| s.date == new_snapshot.date) {
        existing.checking = new_snapshot.checking;
        existing.credit_available = new_snapshot.credit_available;
        existing.credit_limit = new_snapshot.credit_limit;
        existing.personal_debt = new_snapshot.personal_debt;
        existing.note = new_snapshot.note;
    } else {
        let snapshot = BalanceSnapshot {
            id: data.next_snapshot_id,
            date: new_snapshot.date,
            checking: new_snapshot.checking,
            credit_available: new_snapshot.credit_available,
            credit_limit: new_snapshot.credit_limit,
            personal_debt: new_snapshot.personal_debt,
            note: new_snapshot.note,
        };

        data.next_snapshot_id += 1;
        data.balance_snapshots.push(snapshot);
        data.balance_snapshots.sort_by(|a, b| a.date.cmp(&b.date));
    }

    data.save();
    (StatusCode::OK, Json(ApiResponse { ok: true }))
}

async fn delete_balance_snapshot(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> (StatusCode, Json<ApiResponse>) {
    let mut data = state.write().unwrap();

    let original_len = data.balance_snapshots.len();
    data.balance_snapshots.retain(|s| s.id != id);

    if data.balance_snapshots.len() == original_len {
        return (StatusCode::NOT_FOUND, Json(ApiResponse { ok: false }));
    }

    data.save();
    (StatusCode::OK, Json(ApiResponse { ok: true }))
}

async fn get_weather() -> (StatusCode, Json<Weather>) {
    let lat = 61.2181;
    let lon = -149.9003;

    let url = format!(
        "https://api.open-meteo.com/v1/forecast?latitude={}&longitude={}&daily=temperature_2m_max,temperature_2m_min&current_weather=true&temperature_unit=fahrenheit&timezone=America/Anchorage&forecast_days=1",
        lat, lon
    );

    let response = match reqwest::get(&url).await {
        Ok(r) => r,
        Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, Json(Weather { current_f: 0, high_f: 0, low_f: 0 })),
    };

    let json: serde_json::Value = match response.json().await {
        Ok(j) => j,
        Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, Json(Weather { current_f: 0, high_f: 0, low_f: 0 })),
    };

    let current = json["current_weather"]["temperature"].as_f64().unwrap_or(0.0) as i32;
    let high = json["daily"]["temperature_2m_max"][0].as_f64().unwrap_or(0.0) as i32;
    let low = json["daily"]["temperature_2m_min"][0].as_f64().unwrap_or(0.0) as i32;

    (StatusCode::OK, Json(Weather { current_f: current, high_f: high, low_f: low }))
}

/// Fetch NWS weather briefing data (forecast + alerts) for Anchorage
async fn get_weather_briefing() -> (StatusCode, Json<WeatherBriefing>) {
    let client = reqwest::Client::new();

    // Anchorage NWS grid coordinates (from api.weather.gov/points/61.21,-149.89)
    let forecast_url = "https://api.weather.gov/gridpoints/AER/143,236/forecast";
    let alerts_url = "https://api.weather.gov/alerts/active?zone=AKZ701,AKZ702"; // Anchorage zones

    let empty_briefing = WeatherBriefing {
        generated_at: chrono::Utc::now().to_rfc3339(),
        alerts: vec![],
        forecast_periods: vec![],
    };

    // Fetch forecast
    let forecast_resp = match client
        .get(forecast_url)
        .header("User-Agent", "personal-finance-display")
        .send()
        .await
    {
        Ok(r) => r,
        Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, Json(empty_briefing)),
    };

    let forecast_json: serde_json::Value = match forecast_resp.json().await {
        Ok(j) => j,
        Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, Json(empty_briefing)),
    };

    // Fetch alerts
    let alerts_resp = match client
        .get(alerts_url)
        .header("User-Agent", "personal-finance-display")
        .send()
        .await
    {
        Ok(r) => r,
        Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, Json(empty_briefing)),
    };

    let alerts_json: serde_json::Value = match alerts_resp.json().await {
        Ok(j) => j,
        Err(_) => return (StatusCode::SERVICE_UNAVAILABLE, Json(empty_briefing)),
    };

    // Parse forecast periods
    let forecast_periods: Vec<ForecastPeriod> = forecast_json["properties"]["periods"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .take(1) // Just today
        .map(|p| ForecastPeriod {
            name: p["name"].as_str().unwrap_or("").to_string(),
            temperature: p["temperature"].as_i64().unwrap_or(0) as i32,
            temperature_unit: p["temperatureUnit"].as_str().unwrap_or("F").to_string(),
            wind_speed: p["windSpeed"].as_str().unwrap_or("").to_string(),
            wind_direction: p["windDirection"].as_str().unwrap_or("").to_string(),
            short_forecast: p["shortForecast"].as_str().unwrap_or("").to_string(),
            detailed_forecast: p["detailedForecast"].as_str().unwrap_or("").to_string(),
            precipitation_chance: p["probabilityOfPrecipitation"]["value"].as_i64().map(|v| v as i32),
            is_daytime: p["isDaytime"].as_bool().unwrap_or(true),
        })
        .collect();

    // Parse alerts
    let alerts: Vec<WeatherAlert> = alerts_json["features"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .map(|a| {
            let props = &a["properties"];
            WeatherAlert {
                event: props["event"].as_str().unwrap_or("").to_string(),
                severity: props["severity"].as_str().unwrap_or("").to_string(),
                headline: props["headline"].as_str().unwrap_or("").to_string(),
                description: props["description"].as_str().unwrap_or("").to_string(),
                instruction: props["instruction"].as_str().map(|s| s.to_string()),
                areas: props["areaDesc"].as_str().unwrap_or("").to_string(),
                ends: props["ends"].as_str().map(|s| s.to_string()),
            }
        })
        .collect();

    let briefing = WeatherBriefing {
        generated_at: chrono::Utc::now().to_rfc3339(),
        alerts,
        forecast_periods,
    };

    (StatusCode::OK, Json(briefing))
}

#[tokio::main]
async fn main() {
    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(3000);

    let data_file = PathBuf::from("data.json");

    let state: AppState = Arc::new(RwLock::new(AppData::load(data_file)));

    let api_routes = Router::new()
        .route("/data", get(get_data))
        .route("/worklog", post(create_work_log))
        .route("/worklog/:id", delete(delete_work_log))
        .route("/balance", post(create_balance_snapshot))
        .route("/balance/:id", delete(delete_balance_snapshot))
        .route("/weather", get(get_weather))
        .route("/weather-briefing", get(get_weather_briefing));

    let serve_dir = ServeDir::new("dist")
        .append_index_html_on_directories(true)
        .not_found_service(ServeFile::new("dist/index.html"));

    let app = Router::new()
        .nest("/api", api_routes)
        .fallback_service(serve_dir)
        .layer(SetResponseHeaderLayer::if_not_present(
            header::CACHE_CONTROL,
            HeaderValue::from_static("no-cache, no-store, must-revalidate"),
        ))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .unwrap();

    println!("Finance server running at http://localhost:{}", port);
    axum::serve(listener, app).await.unwrap();
}
