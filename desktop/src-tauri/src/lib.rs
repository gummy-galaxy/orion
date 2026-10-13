use std::{
    env, fs,
    net::{Ipv4Addr, TcpListener, TcpStream},
    process::{Child, Command},
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};

use tauri::{Manager, RunEvent, WebviewUrl, WebviewWindowBuilder};

#[cfg(target_os = "macos")]
use objc2::{msg_send, rc::Retained, sel, MainThreadMarker};
#[cfg(target_os = "macos")]
use objc2_foundation::NSString;
#[cfg(target_os = "macos")]
use objc2_web_kit::WKWebViewConfiguration;

mod menu;
mod mouse_navigation;
mod usage;

/// What Activity Monitor calls the window's web content process, in line with WebKit's other
/// "Orion …" processes. Without it, the process goes by the page's address, `http://127.0.0.1:<port>`.
#[cfg(target_os = "macos")]
const WEB_CONTENT_NAME: &str = "Orion Web Content";

/// Where the shell remembers its server's port, beside the window state in the app's own folder.
const PORT_FILE: &str = "server-port";

fn get_free_port() -> std::io::Result<u16> {
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0))?;
    Ok(listener.local_addr()?.port())
}

fn is_port_free(port: u16) -> bool {
    TcpListener::bind((Ipv4Addr::LOCALHOST, port)).is_ok()
}

/// The port the web view loads from, kept the same across launches. WebKit keys browser storage by
/// origin, so a new port each launch would start the canvas's view state empty every time.
fn get_server_port(app: &tauri::App) -> Option<u16> {
    let file = app.path().app_data_dir().ok()?.join(PORT_FILE);
    let saved = fs::read_to_string(&file)
        .ok()
        .and_then(|text| text.trim().parse::<u16>().ok())
        .filter(|&port| port != 0);

    if let Some(port) = saved {
        // A server left by a crashed launch exits within a couple of seconds of noticing.
        let deadline = Instant::now() + Duration::from_secs(3);
        loop {
            if is_port_free(port) {
                return Some(port);
            }
            if Instant::now() >= deadline {
                break;
            }
            thread::sleep(Duration::from_millis(200));
        }
    }

    let port = get_free_port().ok()?;
    if let Some(dir) = file.parent() {
        let _ = fs::create_dir_all(dir);
    }
    let _ = fs::write(&file, port.to_string());
    Some(port)
}

fn stop_server(child: &mut Child) {
    let _ = child.kill();
    let _ = child.wait();
}

fn start_server(app: &tauri::App) -> Option<(Child, WebviewUrl)> {
    let port = get_server_port(app)?;
    let url = format!("http://127.0.0.1:{port}/").parse().ok()?;
    let binary = env::current_exe().ok()?.with_file_name("orion");
    let static_dir = app.path().resource_dir().ok()?.join("dist");

    let mut command = Command::new(binary);
    command.args([
        "serve",
        "--host",
        "127.0.0.1",
        "--port",
        &port.to_string(),
        "--static",
        static_dir.to_str()?,
    ]);

    let mut path = env::var_os("PATH").unwrap_or_default();
    if !path.is_empty() {
        path.push(":");
    }
    path.push("/opt/homebrew/bin:/usr/local/bin");
    command.env("PATH", path);
    if let Some(data_dir) = env::var_os("ORION_DATA_DIR") {
        command.env("ORION_DATA_DIR", data_dir);
    }

    let mut child = command.spawn().ok()?;
    let address = (Ipv4Addr::LOCALHOST, port).into();
    let deadline = Instant::now() + Duration::from_secs(10);
    while Instant::now() < deadline {
        if TcpStream::connect_timeout(&address, Duration::from_millis(100)).is_ok() {
            return Some((child, WebviewUrl::External(url)));
        }
        match child.try_wait() {
            Ok(Some(_)) => return None,
            Err(_) => break,
            Ok(None) => {}
        }
        thread::sleep(Duration::from_millis(100));
    }

    stop_server(&mut child);
    None
}

/// A web view configuration that names the web content process for Activity Monitor.
#[cfg(target_os = "macos")]
fn get_webview_configuration() -> Option<Retained<WKWebViewConfiguration>> {
    let main_thread = MainThreadMarker::new()?;
    let configuration = unsafe { WKWebViewConfiguration::new(main_thread) };
    // A private property, so it's checked before it's set in case a WebKit update drops it.
    let responds: bool =
        unsafe { msg_send![&*configuration, respondsToSelector: sel!(_setProcessDisplayName:)] };
    if responds {
        let name = NSString::from_str(WEB_CONTENT_NAME);
        let _: () = unsafe { msg_send![&*configuration, _setProcessDisplayName: &*name] };
    }
    Some(configuration)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let server = Arc::new(Mutex::new(None::<Child>));
    let server_for_setup = Arc::clone(&server);

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .menu(menu::build)
        .on_menu_event(menu::handle_event)
        .manage(usage::UsageSamples::default())
        .invoke_handler(tauri::generate_handler![usage::process_usage])
        .setup(move |app| {
            let url = if cfg!(debug_assertions) {
                WebviewUrl::App("index.html".into())
            } else if let Some((child, url)) = start_server(app) {
                *server_for_setup.lock().unwrap() = Some(child);
                url
            } else {
                WebviewUrl::App("index.html".into())
            };

            let window = WebviewWindowBuilder::new(app, "main", url)
                .title("Orion")
                .inner_size(1440.0, 900.0)
                .min_inner_size(960.0, 640.0);

            #[cfg(target_os = "macos")]
            let window = match get_webview_configuration() {
                Some(configuration) => window.with_webview_configuration(configuration),
                None => window,
            };

            // The app draws its own window chrome. macOS keeps the traffic lights, centered in the
            // sidebar header; elsewhere the app draws minimize, maximize, and close itself.
            #[cfg(target_os = "macos")]
            let window = window
                .title_bar_style(tauri::TitleBarStyle::Overlay)
                .hidden_title(true)
                .traffic_light_position(tauri::LogicalPosition::new(16.0, 15.0));
            #[cfg(not(target_os = "macos"))]
            let window = window.decorations(false);

            let window = window.build()?;
            mouse_navigation::forward(window);
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building Orion")
        .run(move |_, event| {
            if matches!(event, RunEvent::Exit) {
                if let Some(mut child) = server.lock().unwrap().take() {
                    stop_server(&mut child);
                }
            }
        });
}
