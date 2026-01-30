# Weather Summary Feature - Implementation Status

## Goal

Add a daily AI-generated weather summary to the finance display. The summary should be concise, relevant for morning commute planning in Anchorage, and displayed on the Pi's screen.

## Current Progress

### Completed

1. **Research on LLM providers** - Evaluated OpenRouter, AI/ML API, and PayPerQ (ppq.ai). PayPerQ selected for:
   - Anonymous usage (no signup/KYC required)
   - Bitcoin Lightning payments
   - OpenAI-compatible API
   - ~$0.02/query average cost

2. **NWS data fetching implemented in Rust backend** - New endpoint `/api/weather-briefing` that fetches:
   - Today's forecast from NWS API (`api.weather.gov/gridpoints/AER/143,236/forecast`)
   - Active alerts for Anchorage zones (AKZ701, AKZ702)

3. **New types added**:
   - `ForecastPeriod` - temperature, wind, precipitation chance, detailed forecast
   - `WeatherAlert` - event type, severity, description, instructions
   - `WeatherBriefing` - container with generated timestamp, alerts list, forecast periods

4. **Elm types auto-generated** via elm_rs (ready for frontend use)

### Not Yet Implemented

1. **PayPerQ integration** - Need to:
   - Set up PayPerQ account and fund with crypto
   - Store API key securely on Pi (not in repo)
   - Add LLM call to backend that sends weather data and receives summary

2. **LLM prompt engineering** - Draft prompt exists conceptually:
   > "You are a concise morning weather briefer for someone commuting in Anchorage. Summarize today's forecast and any alerts. Focus on: temperature, precipitation, road-relevant conditions (ice, snow, wind), and anything unusual. Keep it under 100 words."

3. **Display on graph page** - Need to decide where/how to show the summary

4. **Scheduling** - When to generate the summary (cron job? on-demand? cache for the day?)

## Files Modified This Session

- `backend/src/types.rs` - Added ForecastPeriod, WeatherAlert, WeatherBriefing
- `backend/src/main.rs` - Added `/api/weather-briefing` endpoint
- `backend/src/generate_elm.rs` - Added new types to Elm generation
- `backend/Cargo.toml` - Added chrono dependency
- `frontend/src/Graph.elm` - Fixed bug where days with work logs but no balance snapshot weren't showing incoming pay

## Testing

The `/api/weather-briefing` endpoint works and returns live NWS data. Example output structure:

```json
{
  "generatedAt": "2026-01-29T17:52:51...",
  "alerts": [{
    "event": "Winter Weather Advisory",
    "severity": "Moderate",
    "description": "* WHAT...Freezing rain...",
    "instruction": "Slow down and use caution..."
  }],
  "forecastPeriods": [{
    "name": "Today",
    "temperature": 33,
    "shortForecast": "Partly Sunny then Freezing Rain Likely",
    "detailedForecast": "..."
  }]
}
```

## Next Steps

1. Manager sets up PayPerQ account and provides API key
2. Add LLM integration to backend (call PayPerQ with weather data, get summary)
3. Add summary display to frontend
4. Deploy and test on Pi
