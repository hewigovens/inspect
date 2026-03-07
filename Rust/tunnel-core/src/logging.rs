use log::{Level, LevelFilter};
use once_cell::sync::Lazy;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::sync::atomic::{AtomicU8, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

static RUST_LOG_PATH: Lazy<Mutex<Option<PathBuf>>> = Lazy::new(|| Mutex::new(None));
static RUST_LOGGER: SharedRustFileLogger = SharedRustFileLogger;
static RUST_LOG_LEVEL: AtomicU8 = AtomicU8::new(level_filter_to_u8(LevelFilter::Error));

pub fn append_critical_log(path: Option<&Path>, scope: &str, message: &str) {
    append_log(path, scope, Level::Error, message);
}

pub fn append_verbose_log(path: Option<&Path>, scope: &str, message: &str) {
    append_log(path, scope, Level::Debug, message);
}

pub fn configure_rust_logger(path: Option<PathBuf>, level: LevelFilter) {
    *RUST_LOG_PATH.lock().expect("rust log path lock poisoned") = path;
    RUST_LOG_LEVEL.store(level_filter_to_u8(level), Ordering::Relaxed);

    if log::set_logger(&RUST_LOGGER).is_ok() {
        log::set_max_level(level);
        return;
    }

    log::set_max_level(level);
}

fn append_log(path: Option<&Path>, scope: &str, level: Level, message: &str) {
    if should_write(level) == false {
        return;
    }

    let Some(path) = path else {
        return;
    };

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs_f64())
        .unwrap_or_default();

    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
        let _ = writeln!(file, "[{timestamp:.3}] [{scope}] [{}] {message}", level.as_str());
    }
}

fn should_write(level: Level) -> bool {
    level_filter_from_u8(RUST_LOG_LEVEL.load(Ordering::Relaxed)) >= level.to_level_filter()
}

const fn level_filter_to_u8(level: LevelFilter) -> u8 {
    match level {
        LevelFilter::Off => 0,
        LevelFilter::Error => 1,
        LevelFilter::Warn => 2,
        LevelFilter::Info => 3,
        LevelFilter::Debug => 4,
        LevelFilter::Trace => 5,
    }
}

const fn level_filter_from_u8(value: u8) -> LevelFilter {
    match value {
        0 => LevelFilter::Off,
        1 => LevelFilter::Error,
        2 => LevelFilter::Warn,
        3 => LevelFilter::Info,
        4 => LevelFilter::Debug,
        _ => LevelFilter::Trace,
    }
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
            record.level(),
            &format!("{}", record.args()),
        );
    }

    fn flush(&self) {}
}
