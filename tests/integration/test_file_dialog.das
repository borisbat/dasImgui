options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public
require strings

//! Integration smoke for the native `imgui_file_dialog` component, driven
//! entirely through `imgui_playwright` (proving the dialog is registry-backed,
//! not raw ImGui). Boots the tutorial demo, opens the dialog in open mode
//! (asserts the breadcrumb / sortable table / OK button register), cancels,
//! then opens save mode, types a filename, confirms, and checks the demo's
//! result text echoes the typed name. GL + a window are required, so this is a
//! LOCAL rail — macOS CI has no GL.

let FILE_DIALOG_FEATURE = "modules/dasImgui/examples/tutorial/file_dialog.das"

def private result_value(app : ImguiApp) : string {
    var s = snapshot(app)
    return widget_payload_field(s, "FDLG_WIN/RESULT", "value") ?? ""
}

def private wait_result(app : ImguiApp; needle : string) : bool {
    for (_ in range(120)) {
        if (find(result_value(app), needle) >= 0) {
            return true
        }
    }
    return false
}

def private count_crumbs(app : ImguiApp) : int {
    var s = snapshot(app)
    var n = 0
    for (i in range(64)) {
        if (!widget_exists(s, "FILEDLG/CRUMB[{i}]")) {
            break
        }
        n++
    }
    return n
}

// First file row whose Type cell reads "Folder" — entry indices are contiguous
// (0..n-1), so scan the TYPE_CELL[i] payloads on one snapshot.
def private find_folder_row(app : ImguiApp) : string {
    var s = snapshot(app)
    for (i in range(400)) {
        let cell = "FILEDLG/FILE_TABLE/TYPE_CELL[{i}]"
        if (!widget_exists(s, cell)) {
            continue
        }
        if ((widget_payload_field(s, cell, "value") ?? "") == "Folder") {
            return "FILEDLG/FILE_TABLE/ROW[{i}]"
        }
    }
    return ""
}

[test]
def test_file_dialog(t : T?) {
    with_imgui_app(FILE_DIALOG_FEATURE) $(d) {
        // demo window + the three trigger buttons render
        var snap = wait_for_widget(d, "FDLG_WIN/BTN_OPEN", 15.0f)
        t |> success(snap != null, "demo window + Open trigger render")
        if (snap == null) {
            return
        }
        t |> success(widget_exists(snap, "FDLG_WIN/BTN_SAVE"), "Save As trigger present")
        t |> success(widget_exists(snap, "FDLG_WIN/BTN_CREATE"), "New trigger present")

        // --- open mode: the dialog is fully registry-backed ---
        click(d, "FDLG_WIN/BTN_OPEN")
        var od = wait_for_widget(d, "FILEDLG/FILE_TABLE", 10.0f)
        t |> success(od != null, "open dialog renders the sortable file table (FILEDLG/FILE_TABLE)")
        if (od != null) {
            t |> success(widget_exists(od, "FILEDLG/UP"), "breadcrumb '..' button present")
            t |> success(widget_exists(od, "FILEDLG/BTN_OK"), "OK button present")
            t |> success(widget_exists(od, "FILEDLG/BTN_CANCEL"), "Cancel button present")

            // folder double-click enters the directory — regresses the row-loop
            // rebuild crash (navigate_to mutating entries/view mid-iteration).
            let folder = find_folder_row(d)
            if (!empty(folder)) {
                let before = count_crumbs(d)
                double_click(d, folder)
                var entered = false
                for (_ in range(180)) {
                    if (count_crumbs(d) > before) {
                        entered = true
                        break
                    }
                }
                t |> success(entered, "folder double-click enters the dir without crashing ({folder})")
            }

            // breadcrumb click navigates — regresses the crumb-loop rebuild crash.
            // A surviving table after the click proves the body didn't throw.
            if (widget_exists(snapshot(d), "FILEDLG/CRUMB[0]")) {
                click(d, "FILEDLG/CRUMB[0]")
                t |> success(wait_for_widget(d, "FILEDLG/FILE_TABLE", 5.0f) != null,
                    "breadcrumb click navigates without crashing")
            }
        }
        click(d, "FILEDLG/BTN_CANCEL")
        t |> success(wait_result(d, "cancelled"), "Cancel returns the cancelled result")

        // --- save mode: type a name + confirm, result echoes the name ---
        click(d, "FDLG_WIN/BTN_SAVE")
        var sd = wait_for_widget(d, "FILEDLG/NAME_FIELD", 10.0f)
        t |> success(sd != null, "save dialog renders the filename field (FILEDLG/NAME_FIELD)")
        force_set_value(d, "FILEDLG/NAME_FIELD", JV("zzz_unit_test"))
        click(d, "FILEDLG/BTN_OK")
        t |> success(wait_result(d, "zzz_unit_test"), "save confirm returns a path containing the typed name")
    }
}
