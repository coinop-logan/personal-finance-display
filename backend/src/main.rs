mod types;

use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{delete, get, post},
    Json, Router,
};
use std::sync::{Arc, RwLock};
use std::{fs, path::PathBuf};
use tower_http::services::{ServeDir, ServeFile};
use types::{ApiResponse, Entry, NewEntry};

type AppState = Arc<RwLock<AppData>>;

struct AppData {
    entries: Vec<Entry>,
    next_id: i32,
    data_file: PathBuf,
}

impl AppData {
    fn load(data_file: PathBuf) -> Self {
        let entries: Vec<Entry> = if data_file.exists() {
            let content = fs::read_to_string(&data_file).unwrap_or_default();
            serde_json::from_str(&content).unwrap_or_default()
        } else {
            Vec::new()
        };

        let next_id = entries.iter().map(|e| e.id).max().unwrap_or(0) + 1;

        Self {
            entries,
            next_id,
            data_file,
        }
    }

    fn save(&self) {
        let content = serde_json::to_string_pretty(&self.entries).unwrap();
        fs::write(&self.data_file, content).ok();
    }
}

async fn get_entries(State(state): State<AppState>) -> Json<Vec<Entry>> {
    let data = state.read().unwrap();
    Json(data.entries.clone())
}

async fn create_entry(
    State(state): State<AppState>,
    Json(new_entry): Json<NewEntry>,
) -> (StatusCode, Json<ApiResponse>) {
    let mut data = state.write().unwrap();

    let entry = Entry {
        id: data.next_id,
        date: new_entry.date,
        checking: new_entry.checking,
        credit_available: new_entry.credit_available,
        hours_worked: new_entry.hours_worked,
        pay_per_hour: new_entry.pay_per_hour,
        other_incoming: new_entry.other_incoming,
        note: new_entry.note,
    };

    data.next_id += 1;
    data.entries.push(entry);
    data.entries.sort_by(|a, b| a.date.cmp(&b.date));
    data.save();

    (StatusCode::OK, Json(ApiResponse { ok: true }))
}

async fn delete_entry(
    State(state): State<AppState>,
    Path(id): Path<i32>,
) -> (StatusCode, Json<ApiResponse>) {
    let mut data = state.write().unwrap();

    let original_len = data.entries.len();
    data.entries.retain(|e| e.id != id);

    if data.entries.len() == original_len {
        return (StatusCode::NOT_FOUND, Json(ApiResponse { ok: false }));
    }

    data.save();
    (StatusCode::OK, Json(ApiResponse { ok: true }))
}

#[tokio::main]
async fn main() {
    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(3000);

    // Data file location - same directory as server for simplicity
    let data_file = PathBuf::from("data.json");

    let state: AppState = Arc::new(RwLock::new(AppData::load(data_file)));

    // API routes
    let api_routes = Router::new()
        .route("/data", get(get_entries))
        .route("/entry", post(create_entry))
        .route("/entry/{id}", delete(delete_entry));

    // Main app: API + static files (with SPA fallback to index.html)
    let serve_dir = ServeDir::new("dist")
        .append_index_html_on_directories(true)
        .not_found_service(ServeFile::new("dist/index.html"));

    let app = Router::new()
        .nest("/api", api_routes)
        .fallback_service(serve_dir)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .unwrap();

    println!("Finance server running at http://localhost:{}", port);
    axum::serve(listener, app).await.unwrap();
}
