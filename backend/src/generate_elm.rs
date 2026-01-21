//! Generates Elm types and decoders from Rust types.
//! Run with: cargo run --bin generate-elm

mod types;

use elm_rs::{Elm, ElmDecode, ElmEncode};
use std::fs;
use std::path::Path;

fn main() {
    let mut elm_code = String::new();

    elm_code.push_str(
        r#"module Api.Types exposing (..)

{-| Auto-generated from Rust types. DO NOT EDIT MANUALLY.

    To regenerate, run: make generate-elm
    (or: cd backend && cargo run --bin generate-elm)
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


"#,
    );

    let add = |code: &mut String, opt: Option<String>| {
        if let Some(s) = opt {
            let fixed = s
                .replace("Json.Decode.", "Decode.")
                .replace("Json.Encode.", "Encode.");
            code.push_str(&fixed);
            code.push_str("\n\n");
        }
    };

    // Job
    add(&mut elm_code, types::Job::elm_definition());
    add(&mut elm_code, types::Job::decoder_definition());
    add(&mut elm_code, types::Job::encoder_definition());

    // WorkLog
    add(&mut elm_code, types::WorkLog::elm_definition());
    add(&mut elm_code, types::WorkLog::decoder_definition());
    add(&mut elm_code, types::WorkLog::encoder_definition());

    // NewWorkLog
    add(&mut elm_code, types::NewWorkLog::elm_definition());
    add(&mut elm_code, types::NewWorkLog::decoder_definition());
    add(&mut elm_code, types::NewWorkLog::encoder_definition());

    // BalanceSnapshot
    add(&mut elm_code, types::BalanceSnapshot::elm_definition());
    add(&mut elm_code, types::BalanceSnapshot::decoder_definition());
    add(&mut elm_code, types::BalanceSnapshot::encoder_definition());

    // NewBalanceSnapshot
    add(&mut elm_code, types::NewBalanceSnapshot::elm_definition());
    add(&mut elm_code, types::NewBalanceSnapshot::decoder_definition());
    add(&mut elm_code, types::NewBalanceSnapshot::encoder_definition());

    // FinanceData
    add(&mut elm_code, types::FinanceData::elm_definition());
    add(&mut elm_code, types::FinanceData::decoder_definition());
    add(&mut elm_code, types::FinanceData::encoder_definition());

    // ApiResponse
    add(&mut elm_code, types::ApiResponse::elm_definition());
    add(&mut elm_code, types::ApiResponse::encoder_definition());

    // Weather
    add(&mut elm_code, types::Weather::elm_definition());
    add(&mut elm_code, types::Weather::decoder_definition());
    add(&mut elm_code, types::Weather::encoder_definition());

    let output_dir = Path::new("../frontend/src/Api");
    fs::create_dir_all(output_dir).expect("Failed to create Api directory");

    let output_path = output_dir.join("Types.elm");
    fs::write(&output_path, elm_code).expect("Failed to write Elm file");

    println!("Generated: {}", output_path.display());
}
