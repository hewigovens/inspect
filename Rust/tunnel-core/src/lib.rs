pub mod core;
pub mod flow;
pub mod live;
pub mod logging;
pub mod model;
pub mod packet;
pub mod pcap;
pub mod tun2proxy_live;
pub mod tun2proxy_observer;

use core::{CORE_VERSION, InspectTunnelCore};
use logging::append_critical_log;
use model::{InspectTunnelCoreConfig, InspectTunnelCoreStats};
use once_cell::sync::Lazy;
use std::ffi::{CStr, c_char, c_int};
use std::path::PathBuf;
use std::sync::Mutex;

static CORE_STATE: Lazy<Mutex<GlobalCoreState>> =
    Lazy::new(|| Mutex::new(GlobalCoreState::default()));
static VERSION: &[u8] = b"tunnel-core/0.2.0-dev\0";

#[derive(Default)]
struct GlobalCoreState {
    core: InspectTunnelCore,
    last_error: Vec<u8>,
    drained_observations_json: Vec<u8>,
}

fn set_error(state: &mut GlobalCoreState, message: impl Into<String>) -> c_int {
    let text = message.into();
    state.last_error = text.clone().into_bytes();
    state.last_error.push(0);
    append_critical_log(state.core.log_file_path(), "RustCore", &text);
    -1
}

fn clear_error(state: &mut GlobalCoreState) {
    state.last_error.clear();
}

fn read_c_string<'a>(ptr: *const c_char) -> Result<&'a str, &'static str> {
    if ptr.is_null() {
        return Err("received null pointer");
    }

    let c_str = unsafe { CStr::from_ptr(ptr) };
    c_str.to_str().map_err(|_| "received invalid UTF-8")
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_version() -> *const c_char {
    let _ = CORE_VERSION;
    VERSION.as_ptr() as *const c_char
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_last_error_message() -> *const c_char {
    let state = CORE_STATE.lock().expect("core state mutex poisoned");
    if state.last_error.is_empty() {
        std::ptr::null()
    } else {
        state.last_error.as_ptr() as *const c_char
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_set_log_file(path: *const c_char) -> c_int {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    clear_error(&mut state);

    let path = match read_c_string(path) {
        Ok(value) if !value.trim().is_empty() => value,
        Ok(_) => return set_error(&mut state, "log file path must not be empty"),
        Err(error) => return set_error(&mut state, error),
    };

    match state.core.set_log_file_path(PathBuf::from(path)) {
        Ok(()) => 0,
        Err(error) => set_error(&mut state, error),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_set_tun_fd(fd: c_int) -> c_int {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    clear_error(&mut state);

    match state.core.set_tun_fd(fd) {
        Ok(()) => 0,
        Err(error) => set_error(&mut state, error),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_start(config_json: *const c_char) -> c_int {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    clear_error(&mut state);

    let config_str = match read_c_string(config_json) {
        Ok(value) if !value.trim().is_empty() => value,
        Ok(_) => return set_error(&mut state, "config must not be empty"),
        Err(error) => return set_error(&mut state, error),
    };

    let config = match serde_json::from_str::<InspectTunnelCoreConfig>(config_str) {
        Ok(config) => config,
        Err(error) => return set_error(&mut state, format!("invalid config JSON: {error}")),
    };

    match state.core.start(config) {
        Ok(()) => 0,
        Err(error) => set_error(&mut state, error),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_start_live_loop() -> c_int {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    clear_error(&mut state);

    match state.core.start_live_loop() {
        Ok(()) => 0,
        Err(error) => set_error(&mut state, error),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_stop() {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    state.core.stop();
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_get_stats(out_stats: *mut InspectTunnelCoreStats) -> c_int {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    clear_error(&mut state);

    if out_stats.is_null() {
        return set_error(&mut state, "stats output pointer must not be null");
    }

    unsafe {
        std::ptr::write(out_stats, state.core.stats());
    }

    0
}

#[unsafe(no_mangle)]
pub extern "C" fn tunnel_core_drain_observations_json() -> *const c_char {
    let mut state = CORE_STATE.lock().expect("core state mutex poisoned");
    clear_error(&mut state);

    let observations = state.core.drain_live_observations();
    if observations.is_empty() {
        state.drained_observations_json.clear();
        return std::ptr::null();
    }

    match serde_json::to_vec(&observations) {
        Ok(mut payload) => {
            payload.push(0);
            state.drained_observations_json = payload;
            state.drained_observations_json.as_ptr() as *const c_char
        }
        Err(error) => {
            let _ = set_error(
                &mut state,
                format!("failed to encode drained observations: {error}"),
            );
            std::ptr::null()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn start_requires_tun_fd() {
        tunnel_core_stop();
        let config = CString::new(
            r#"{"ipv4Address":"198.18.0.1","ipv6Address":"fd00::1","dnsAddress":"198.18.0.2","fakeIpRange":"198.18.0.0/16","mtu":1500,"monitorEnabled":true}"#,
        )
        .unwrap();

        assert_eq!(tunnel_core_start(config.as_ptr()), -1);
        let last_error = unsafe { CStr::from_ptr(tunnel_core_last_error_message()) }
            .to_str()
            .unwrap();
        assert!(last_error.contains("tun fd"));
    }

    #[test]
    fn start_and_read_stats() {
        let log_path = CString::new("/tmp/tunnel-core-test.log").unwrap();
        let config = CString::new(
            r#"{"ipv4Address":"198.18.0.1","ipv6Address":"fd00::1","dnsAddress":"198.18.0.2","fakeIpRange":"198.18.0.0/16","mtu":1500,"monitorEnabled":true}"#,
        )
        .unwrap();

        assert_eq!(tunnel_core_set_log_file(log_path.as_ptr()), 0);
        assert_eq!(tunnel_core_set_tun_fd(5), 0);
        assert_eq!(tunnel_core_start(config.as_ptr()), 0);

        let mut stats = InspectTunnelCoreStats::default();
        assert_eq!(tunnel_core_get_stats(&mut stats), 0);
        assert_eq!(stats.tx_packets, 0);
        assert_eq!(stats.rx_packets, 0);

        tunnel_core_stop();
    }

    #[test]
    fn start_live_loop_requires_started_core() {
        tunnel_core_stop();

        assert_eq!(tunnel_core_start_live_loop(), -1);
        let last_error = unsafe { CStr::from_ptr(tunnel_core_last_error_message()) }
            .to_str()
            .unwrap();
        assert!(last_error.contains("started before live loop"));
    }
}
