use once_cell::sync::Lazy;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

static RUST_LOG_PATH: Lazy<Mutex<Option<PathBuf>>> = Lazy::new(|| Mutex::new(None));
static RUST_LOGGER: SharedRustFileLogger = SharedRustFileLogger;

pub fn append_log(path: Option<&Path>, scope: &str, message: &str) {
    let Some(path) = path else {
        return;
    };

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs_f64())
        .unwrap_or_default();

    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
        let _ = writeln!(file, "[{timestamp:.3}] [{scope}] {message}");
    }
}

pub fn configure_rust_logger(path: Option<PathBuf>, level: log::LevelFilter) {
    *RUST_LOG_PATH.lock().expect("rust log path lock poisoned") = path;

    if log::set_logger(&RUST_LOGGER).is_ok() {
        log::set_max_level(level);
        return;
    }

    log::set_max_level(level);
}

struct SharedRustFileLogger;

impl log::Log for SharedRustFileLogger {
    fn enabled(&self, metadata: &log::Metadata<'_>) -> bool {
        metadata.level() <= log::max_level()
    }

    fn log(&self, record: &log::Record<'_>) {
        if self.enabled(record.metadata()) == false {
            return;
        }

        let path = RUST_LOG_PATH
            .lock()
            .expect("rust log path lock poisoned")
            .clone();
        let Some(path) = path else {
            return;
        };

        let target = if record.target().is_empty() {
            "RustLog"
        } else {
            record.target()
        };
        append_log(
            Some(path.as_path()),
            target,
            &format!("{}: {}", record.level(), record.args()),
        );
    }

    fn flush(&self) {}
}
