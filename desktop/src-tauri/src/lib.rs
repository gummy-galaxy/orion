mod store;

use serde_json::Value;

#[tauri::command]
fn orion_workspaces() -> Result<store::WorkspaceList, String> {
    store::workspaces()
}

#[tauri::command]
fn orion_set_active_workspace(name: String) -> Result<store::WorkspaceList, String> {
    store::set_active_workspace(&name)
}

#[tauri::command]
fn orion_create_workspace(name: String, label: String) -> Result<store::WorkspaceList, String> {
    store::create_workspace(&name, &label)
}

#[tauri::command]
fn orion_load(workspace: String) -> Result<Option<Value>, String> {
    store::load(&workspace)
}

#[tauri::command]
fn orion_revision() -> Result<Option<u64>, String> {
    store::revision()
}

#[tauri::command]
fn orion_save(
    workspace: String,
    base_revision: Option<u64>,
    saved: Value,
) -> Result<Value, String> {
    store::save(&workspace, base_revision, saved)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            orion_workspaces,
            orion_set_active_workspace,
            orion_create_workspace,
            orion_load,
            orion_revision,
            orion_save
        ])
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .run(tauri::generate_context!())
        .expect("error while running Orion");
}
