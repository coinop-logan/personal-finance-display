//! Generates Elm types and decoders from Rust types.
//! Run with: cargo run --bin generate-elm

mod types;

use elm_rs::{Elm, ElmDecode, ElmEncode};
use std::fs;
use std::path::Path;

fn main() {
    // Collect all the Elm type definitions
    let mut elm_code = String::new();

    // Module header
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

    // Helper to unwrap Option<String> from elm_rs and fix naming
    let add = |code: &mut String, opt: Option<String>| {
        if let Some(s) = opt {
            // elm_rs generates Json.Decode.xxx and Json.Encode.xxx
            // but our imports alias them to Decode and Encode
            let fixed = s
                .replace("Json.Decode.", "Decode.")
                .replace("Json.Encode.", "Encode.");
            code.push_str(&fixed);
            code.push_str("\n\n");
        }
    };

    // Generate types and decoders for Entry
    add(&mut elm_code, types::Entry::elm_definition());
    add(&mut elm_code, types::Entry::decoder_definition());
    add(&mut elm_code, types::Entry::encoder_definition());

    // Generate types and decoders for NewEntry
    add(&mut elm_code, types::NewEntry::elm_definition());
    add(&mut elm_code, types::NewEntry::decoder_definition());
    add(&mut elm_code, types::NewEntry::encoder_definition());

    // Generate types and encoder for ApiResponse (no decoder needed)
    add(&mut elm_code, types::ApiResponse::elm_definition());
    add(&mut elm_code, types::ApiResponse::encoder_definition());

    // Write to frontend
    let output_dir = Path::new("../frontend/src/Api");
    fs::create_dir_all(output_dir).expect("Failed to create Api directory");

    let output_path = output_dir.join("Types.elm");
    fs::write(&output_path, elm_code).expect("Failed to write Elm file");

    println!("Generated: {}", output_path.display());
}
