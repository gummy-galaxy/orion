use tauri::{
    menu::{AboutMetadata, Menu, MenuItemKind, PredefinedMenuItem},
    AppHandle, Runtime,
};

/// Tauri's default menu, with an About item that shows the commit Orion was built from beside its
/// version. Credits are left out so macOS shows the bundled `Credits.rtf`.
pub fn menu<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<Menu<R>> {
    let menu = Menu::default(app)?;
    if !cfg!(target_os = "macos") {
        return Ok(menu);
    }

    let Some(MenuItemKind::Submenu(app_menu)) = menu.items()?.into_iter().next() else {
        return Ok(menu);
    };

    let package = app.package_info();
    let metadata = AboutMetadata {
        name: Some(package.name.clone()),
        version: Some(package.version.to_string()),
        short_version: option_env!("ORION_COMMIT").map(String::from),
        copyright: app.config().bundle.copyright.clone(),
        ..Default::default()
    };
    let about = PredefinedMenuItem::about(app, None, Some(metadata))?;

    app_menu.remove_at(0)?;
    app_menu.insert(&about, 0)?;
    Ok(menu)
}
