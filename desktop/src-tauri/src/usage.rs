//! CPU and memory for the app and the WebKit processes that draw it, for the debug bar.

use serde::Serialize;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Instant;
use tauri::{State, WebviewWindow};

#[derive(Serialize)]
pub struct ProcessUsage {
    name: &'static str,
    /// Percent of one core since the last sample, as Activity Monitor shows it. Absent on a process's first sample.
    cpu: Option<f64>,
    /// Physical footprint in bytes, which is Activity Monitor's Memory column.
    memory: u64,
}

/// Each process's CPU time at the last sample, to turn the next one into a rate.
#[derive(Default)]
pub struct UsageSamples(Mutex<HashMap<i32, (Instant, u64)>>);

#[tauri::command]
pub async fn process_usage(
    window: WebviewWindow,
    samples: State<'_, UsageSamples>,
) -> Result<Vec<ProcessUsage>, String> {
    let mut processes = vec![("App", std::process::id() as i32)];
    processes.extend(platform::webkit_processes(&window));
    let now = Instant::now();
    let mut last = samples.0.lock().map_err(|e| e.to_string())?;
    let mut next = HashMap::new();
    let usage = processes
        .into_iter()
        .filter_map(|(name, pid)| {
            let (cpu_ns, memory) = platform::rusage(pid)?;
            let cpu = last.get(&pid).and_then(|&(at, was)| {
                let wall = now.duration_since(at).as_nanos() as f64;
                (wall > 0.0).then(|| cpu_ns.saturating_sub(was) as f64 / wall * 100.0)
            });
            next.insert(pid, (now, cpu_ns));
            Some(ProcessUsage { name, cpu, memory })
        })
        .collect();
    *last = next;
    Ok(usage)
}

#[cfg(target_os = "macos")]
mod platform {
    use objc2::msg_send;
    use objc2::runtime::{AnyObject, Sel};
    use objc2::sel;
    use std::sync::mpsc;
    use std::time::Duration;
    use tauri::WebviewWindow;

    /// WebKit's helper processes for this window, read through WKWebView's private process identifiers.
    pub fn webkit_processes(window: &WebviewWindow) -> Vec<(&'static str, i32)> {
        let (send, receive) = mpsc::channel();
        let asked = window.with_webview(move |webview| {
            let view = webview.inner() as *const AnyObject;
            let Some(view) = (unsafe { view.as_ref() }) else {
                return;
            };
            // Private properties, so each is checked before it's read in case a WebKit update drops it.
            let responds = |selector: Sel| -> bool {
                unsafe { msg_send![view, respondsToSelector: selector] }
            };
            let mut found = Vec::new();
            if responds(sel!(_webProcessIdentifier)) {
                found.push(("Web content", unsafe {
                    msg_send![view, _webProcessIdentifier]
                }));
            }
            if responds(sel!(_gpuProcessIdentifier)) {
                found.push(("Graphics", unsafe {
                    msg_send![view, _gpuProcessIdentifier]
                }));
            }
            if responds(sel!(_networkProcessIdentifier)) {
                found.push(("Network", unsafe {
                    msg_send![view, _networkProcessIdentifier]
                }));
            }
            found.retain(|&(_, pid): &(&str, i32)| pid > 0);
            let _ = send.send(found);
        });
        if asked.is_err() {
            return Vec::new();
        }
        receive
            .recv_timeout(Duration::from_millis(500))
            .unwrap_or_default()
    }

    #[repr(C)]
    struct Timebase {
        numer: u32,
        denom: u32,
    }

    extern "C" {
        fn mach_timebase_info(info: *mut Timebase) -> libc::c_int;
    }

    /// CPU time in nanoseconds and physical footprint in bytes.
    pub fn rusage(pid: i32) -> Option<(u64, u64)> {
        let mut info: libc::rusage_info_v4 = unsafe { std::mem::zeroed() };
        let buffer = &mut info as *mut libc::rusage_info_v4 as *mut libc::rusage_info_t;
        if unsafe { libc::proc_pid_rusage(pid, libc::RUSAGE_INFO_V4, buffer) } != 0 {
            return None;
        }
        // CPU times count Mach ticks, which aren't nanoseconds on Apple silicon.
        let mut timebase = Timebase { numer: 0, denom: 0 };
        unsafe { mach_timebase_info(&mut timebase) };
        if timebase.denom == 0 {
            return None;
        }
        let ticks = (info.ri_user_time + info.ri_system_time) as u128;
        Some((
            (ticks * timebase.numer as u128 / timebase.denom as u128) as u64,
            info.ri_phys_footprint,
        ))
    }
}

#[cfg(not(target_os = "macos"))]
mod platform {
    use tauri::WebviewWindow;

    pub fn webkit_processes(_window: &WebviewWindow) -> Vec<(&'static str, i32)> {
        Vec::new()
    }

    pub fn rusage(_pid: i32) -> Option<(u64, u64)> {
        None
    }
}
