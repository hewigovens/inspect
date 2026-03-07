use tunnel_core::core::InspectTunnelCore;
use tunnel_core::model::ReplayScenario;
use std::env;
use std::fs;
use std::path::Path;
use std::process::ExitCode;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("tunnel-core-replay: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    let scenario_path = match args.next() {
        Some(value) => value,
        None => {
            return Err(
                "usage: cargo run --manifest-path Rust/tunnel-core/Cargo.toml --bin tunnel-core-replay -- <scenario.json> [--pretty]".to_string(),
            )
        }
    };
    let pretty = args.any(|arg| arg == "--pretty");

    let scenario_data = fs::read_to_string(&scenario_path)
        .map_err(|error| format!("failed to read scenario at {scenario_path}: {error}"))?;
    let scenario: ReplayScenario = serde_json::from_str(&scenario_data)
        .map_err(|error| format!("failed to parse scenario JSON: {error}"))?;

    let mut core = InspectTunnelCore::default();
    let base_dir = Path::new(&scenario_path).parent();
    let result = core.run_replay_with_base_dir(scenario, base_dir)?;
    let output = if pretty {
        serde_json::to_string_pretty(&result)
    } else {
        serde_json::to_string(&result)
    }
    .map_err(|error| format!("failed to encode replay result: {error}"))?;

    println!("{output}");
    Ok(())
}
