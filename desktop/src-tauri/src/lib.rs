mod usage;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .manage(usage::UsageSamples::default())
        .invoke_handler(tauri::generate_handler![usage::process_usage])
        .run(tauri::generate_context!())
        .expect("error while running Orion");
}
