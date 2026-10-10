use std::{
    env,
    net::{Ipv4Addr, TcpListener, TcpStream},
    process::{Child, Command},
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};

use tauri::{Manager, RunEvent, WebviewUrl, WebviewWindowBuilder};

mod mouse_navigation;
mod usage;

fn get_free_port() -> std::io::Result<u16> {
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0))?;
    Ok(listener.local_addr()?.port())
}

fn stop_server(child: &mut Child) {
    let _ = child.kill();
    let _ = child.wait();
}

fn start_server(app: &tauri::App) -> Option<(Child, WebviewUrl)> {
    let port = get_free_port().ok()?;
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let server = Arc::new(Mutex::new(None::<Child>));
    let server_for_setup = Arc::clone(&server);

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_window_state::Builder::default().build())
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
