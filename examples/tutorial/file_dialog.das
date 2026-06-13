options gen2

require imgui/imgui_harness
require imgui/imgui_file_dialog

// =============================================================================
// TUTORIAL: file_dialog — native New / Open / Save dialog (boost DSL).
//
// `imgui/imgui_file_dialog` is a reusable, fully `imgui_playwright`-drivable
// file dialog built entirely from boost widgets (popup_modal + data_table +
// selectable_label + input_text + combo + buttons) — no raw-ImGui C++ library,
// so every element shows up in the snapshot registry.
//
// Immediate-mode usage:
//   1. a trigger (button / menu) calls `file_dialog_open(cfg)` with a mode,
//      a start directory, and a list of extension filters;
//   2. `file_dialog_draw()` runs EVERY frame at the top level of update()
//      (outside any window, so the registry path stays a clean `FILEDLG/...`)
//      and returns this frame's `FileDialogResult`;
//   3. on `confirmed`, read `file_dialog_selection()` / `file_dialog_selected_path()`.
//
// open mode multi-selects (Ctrl / Shift, `max_selection`); save / create modes
// take a typed name and confirm-overwrite if it already exists.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/file_dialog.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/file_dialog.das
// =============================================================================

var private g_status = "(nothing selected yet)"

def private das_filters() : array<FileDialogFilter> {
    return <- [FileDialogFilter(caption = "daslang (*.das)", ext = "das"),
        FileDialogFilter(caption = "All files", ext = "")]
}

[export]
def init() {
    harness_init("file_dialog — native New / Open / Save", 760, 560)
}

[export]
def update() {
    if (!harness_begin_frame()) {
        return
    }
    harness_new_frame()

    SetNextWindowSize(ImVec2(440.0f, 200.0f), ImGuiCond.FirstUseEver)
    window(FDLG_WIN, (text = "file_dialog demo", closable = false, flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Open the native file dialog in each mode:"))
        if (button(BTN_OPEN, (text = "Open..."))) {
            file_dialog_open(FileDialogConfig(title = "Open File", start_dir = "",
                filters <- das_filters(), mode = FileDialogMode.open, max_selection = 0))
        }
        same_line()
        if (button(BTN_SAVE, (text = "Save As..."))) {
            file_dialog_open(FileDialogConfig(title = "Save File As", start_dir = "",
                filters <- das_filters(), mode = FileDialogMode.save, max_selection = 1))
        }
        same_line()
        if (button(BTN_CREATE, (text = "New..."))) {
            file_dialog_open(FileDialogConfig(title = "New File", start_dir = "",
                filters <- das_filters(), mode = FileDialogMode.create, max_selection = 1))
        }
        separator(SEP)
        text(RESULT, (text = g_status))
    }

    // The dialog renders at the top level so its registry path is `FILEDLG/...`
    // independent of any window. Poll the result every frame.
    let r = file_dialog_draw()
    if (r == FileDialogResult.confirmed) {
        var sel <- file_dialog_selection()
        g_status = "picked {length(sel)} file(s): {file_dialog_selected_path()}"
        delete sel
    } elif (r == FileDialogResult.cancelled) {
        g_status = "cancelled"
    }

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
