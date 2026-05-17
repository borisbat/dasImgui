options gen2

require imgui/imgui_harness
require app_main_menu

// =============================================================================
// HARNESS: imgui_demo app_main_menu — single-scene driver for the main-menu-bar
//          port. Lives next to app_main_menu.das (sibling require).
// SHOWS:   MAIN_BAR_DEMO + File / Edit menu cascades + the Colors submenu's
//          per-color swatch (paints via GetWindowDrawList / AddRectFilled).
// STANDALONE: daslang.exe modules/dasImgui/examples/imgui_demo/harness_app_main_menu.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/imgui_demo/harness_app_main_menu.das -- --headless --headless-frames=60
// LIVE:       daslang-live modules/dasImgui/examples/imgui_demo/harness_app_main_menu.das
// =============================================================================

[export]
def init() {
    harness_init("imgui_demo - Main Menu Bar", 720, 480)
}

[export]
def update() {
    if (!harness_begin_frame()) return
    harness_apply_synth_io()
    harness_new_frame()
    ShowExampleAppMainMenuBar()
    harness_end_frame()
}

[export]
def shutdown() {
    harness_shutdown()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
