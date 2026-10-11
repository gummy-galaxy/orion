use tauri::{
    menu::{
        AboutMetadata, Menu, MenuEvent, MenuItem, MenuItemKind, PredefinedMenuItem, HELP_SUBMENU_ID,
    },
    AppHandle, Manager, Runtime, Url, WebviewUrl, WebviewWindowBuilder,
};
use tauri_plugin_opener::OpenerExt;

const ACKNOWLEDGEMENTS: &str = "acknowledgements";

/// Tauri's default menu with Help › Acknowledgements, and on macOS an About item that shows the
/// commit Orion was built from beside its version. Credits are left out so macOS shows the bundled
/// `Credits.rtf`.
pub fn build<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<Menu<R>> {
    let menu = Menu::default(app)?;

    if let Some(MenuItemKind::Submenu(help)) = menu.get(HELP_SUBMENU_ID) {
        let acknowledgements = MenuItem::with_id(
            app,
            ACKNOWLEDGEMENTS,
            "Acknowledgements",
            true,
            None::<&str>,
        )?;
        help.append(&acknowledgements)?;
    }

    if cfg!(target_os = "macos") {
        if let Some(MenuItemKind::Submenu(app_menu)) = menu.items()?.into_iter().next() {
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
        }
    }

    Ok(menu)
}

pub fn handle_event<R: Runtime>(app: &AppHandle<R>, event: MenuEvent) {
    if event.id() == ACKNOWLEDGEMENTS {
        let _ = open_acknowledgements(app);
    }
}

/// Shows the license page the desktop build generates into the canvas's assets, reusing the window
/// when it's already open. Links to other sites open in the default browser.
fn open_acknowledgements<R: Runtime>(app: &AppHandle<R>) -> tauri::Result<()> {
    if let Some(window) = app.get_webview_window(ACKNOWLEDGEMENTS) {
        window.unminimize()?;
        return window.set_focus();
    }

    let opener = app.clone();
    WebviewWindowBuilder::new(
        app,
        ACKNOWLEDGEMENTS,
        WebviewUrl::App("acknowledgements.html".into()),
    )
    .title("Acknowledgements")
    .inner_size(640.0, 720.0)
    .min_inner_size(420.0, 320.0)
    .on_navigation(move |url| {
        if is_app_url(url) {
            return true;
        }

        let _ = opener.opener().open_url(url.as_str(), None::<&str>);
        false
    })
    .build()?;
    Ok(())
}

fn is_app_url(url: &Url) -> bool {
    matches!(url.scheme(), "tauri" | "asset")
        || matches!(url.host_str(), Some("tauri.localhost" | "localhost"))
}
