//! The mouse's back and forward buttons. WebKit on older macOS versions reports them to the
//! page as a middle click, so the shell hands them over itself on every version.

use tauri::WebviewWindow;

/// Sends the side buttons to the canvas as `orion:navigate` events instead of to the web view.
#[cfg(target_os = "macos")]
pub fn forward(window: WebviewWindow) {
    use block2::RcBlock;
    use objc2_app_kit::{NSEvent, NSEventMask, NSEventType};
    use std::ptr::{self, NonNull};

    let handler = RcBlock::new(move |event: NonNull<NSEvent>| -> *mut NSEvent {
        // SAFETY: AppKit passes the monitor a live event.
        let event_ref = unsafe { event.as_ref() };
        let direction = match event_ref.buttonNumber() {
            3 => "back",
            4 => "forward",
            _ => return event.as_ptr(),
        };

        if event_ref.r#type() == NSEventType::OtherMouseUp {
            let _ = window.eval(format!(
                "window.dispatchEvent(new CustomEvent('orion:navigate', {{ detail: '{direction}' }}))"
            ));
        }

        ptr::null_mut()
    });

    // SAFETY: the handler returns the event it was given or null.
    let monitor = unsafe {
        NSEvent::addLocalMonitorForEventsMatchingMask_handler(
            NSEventMask::OtherMouseDown | NSEventMask::OtherMouseUp,
            &handler,
        )
    };

    // The monitor lasts as long as the app.
    std::mem::forget(monitor);
}

#[cfg(not(target_os = "macos"))]
pub fn forward(_window: WebviewWindow) {}
