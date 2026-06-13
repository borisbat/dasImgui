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
//! result text echoes the typed name. Runs headless (no GL / no window) — it
//! drives the dialog purely over the live API, so it runs in CI on both ubuntu
//! and macOS via `--headless`, like the rest of the integration suite.

let FILE_DIALOG_FEATURE = "modules/dasImgui/examples/tutorial/file_dialog.das"

// Budgeted poll (poll interval + real timeout) — never a tight busy-loop, which
// in headless can spin to completion before the UI updates (false negative) and
// pegs a core. wait_until_sec is the headless-safe poller (timeline-aware).
def private wait_result(app : ImguiApp; needle : string) : bool {
    return wait_until_sec(app, 5.0f) $(var snap) {
        return find(widget_payload_field(snap, "FDLG_WIN/RESULT", "value") ?? "", needle) >= 0
    } != null
}

def private count_crumbs_in(var snap : JsonValue?) : int {
    var n = 0
    for (i in range(64)) {
        if (!widget_exists(snap, "FILEDLG/CRUMB[{i}]")) {
            break
        }
        n++
    }
    return n
}

def private count_crumbs(app : ImguiApp) : int => count_crumbs_in(snapshot(app))

// TOPMOST reliably-clickable row whose Type cell == "Folder" (want_folder) or is any
// non-folder file. A row is reliably clickable only when its whole bbox sits inside the
// table's visible band: a row straddling the bottom scroll edge is still "rendered" but its
// center can fall outside the clip and the click misses (this is what broke macOS CI — a
// file row near the bottom was picked and the double-click landed nowhere). So:
//  - widget_rendered (painted this frame), not just widget_exists (registered);
//  - row bbox fully within the band, then topmost-by-y.
// The band is bracketed by the NAV_SEP / BOTTOM_SEP separators (leaf widgets with real
// bboxes). The data_table CONTAINER registers a zero bbox — only leaf widgets capture an item
// rect — so clipping against it rejected EVERY row and silently skipped both double-click
// sub-checks; the separators give the actual visible top/bottom instead.
// Returns "" when no matching row is fully visible (e.g. files sit below the fold under a
// many-folder start dir); callers treat that as "skip" rather than fail — no flake.
def private first_row(var snap : JsonValue?; want_folder : bool) : string {
    let nav = snap?["globals"]?["FILEDLG/NAV_SEP"]?["bbox"]
    let bot = snap?["globals"]?["FILEDLG/BOTTOM_SEP"]?["bbox"]
    let t_top = nav?["w"] ?? 0.0f      // bottom edge of NAV_SEP = top of the table band
    let t_bot = bot?["y"] ?? 1.0e9f    // top edge of BOTTOM_SEP = bottom of the table band
    var best = ""
    var best_y = 1.0e9f
    for (i in range(400)) {
        let row = "FILEDLG/FILE_TABLE/ROW[{i}]"
        let cell = "FILEDLG/FILE_TABLE/TYPE_CELL[{i}]"
        if (!widget_exists(snap, cell) || !widget_rendered(snap, row)) {
            continue
        }
        let v = widget_payload_field(snap, cell, "value") ?? ""
        if (empty(v) || (v == "Folder") != want_folder) {
            continue
        }
        let rb = snap?["globals"]?[row]?["bbox"]
        let ry0 = rb?["y"] ?? -1.0e9f
        let ry1 = rb?["w"] ?? 1.0e9f
        if (ry0 < t_top || ry1 > t_bot - 4.0f) {        // not fully inside the clip rect
            continue
        }
        if (ry0 < best_y) {
            best_y = ry0
            best = row
        }
    }
    return best
}

def private find_folder_row(app : ImguiApp) : string => first_row(snapshot(app), true)

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
                let entered = wait_until_sec(d, 5.0f) $(var cs) {
                    return count_crumbs_in(cs) > before
                } != null
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

        // --- save mode: double-clicking an EXISTING file must route through the
        // overwrite-confirm modal, not confirm directly (regression for that gate).
        // Needs a clickably-visible file row; files sort below all folders, so when the
        // start dir has more folders than the table shows (e.g. a repo root) no file is
        // visible and this sub-check skips — it covers the routing wherever a file IS
        // visible (most dirs) without flaking where it isn't. The double_click verb +
        // row-double-click path itself is exercised CI-wide by the open-mode folder case. ---
        click(d, "FDLG_WIN/BTN_SAVE")
        if (wait_for_widget(d, "FILEDLG/FILE_TABLE", 10.0f) != null) {
            force_set_value(d, "FILEDLG/FILTER_COMBO", JV(1))   // widen to "All files"
            var file_snap = wait_until_sec(d, 3.0f) $(var fsnap) {
                return !empty(first_row(fsnap, false))
            }
            if (file_snap != null) {
                let frow = first_row(file_snap, false)
                double_click(d, frow)
                // wait_for_widget auto-dumps the UI state on timeout (set_auto_dump_on_timeout,
                // default on), so a miss here is self-explaining with no per-test dump call.
                let ow = wait_for_widget(d, "FILEDLG/OVERWRITE/OW_YES", 5.0f)
                t |> success(ow != null,
                    "save-mode double-click on an existing file opens overwrite-confirm (not a direct save)")
                click(d, "FILEDLG/OVERWRITE/OW_YES")
                // confirm closed the dialog: the table stops rendering (widget_exists stays
                // true after first render, so check rendered-this-frame, not presence).
                let closed = wait_until_sec(d, 5.0f) $(var csnap) {
                    return !widget_rendered(csnap, "FILEDLG/FILE_TABLE")
                }
                t |> success(closed != null, "overwrite-confirm Yes commits the save and closes the dialog")
            }
        }
    }
}
