options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``popup_modal.apng`` against
//! ``examples/tutorial/popup_modal.das``. Tours a Yes/No confirm modal
//! (non-closable) and an X-button settings modal.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
let MODAL_DWELL_MS = 2200u      //! 2.2s post-modal-open dwell

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    with_recording_app("examples/tutorial/popup_modal.das",
                       "popup_modal.apng", 60) $(app) {
        // window/popup_modal containers finalize without a bbox — anchor
        // every cursor + narration target at a button or text leaf. See
        // PR #67 Copilot round 1.
        let T_OPEN_CONFIRM = "PM_WIN/OPEN_CONFIRM"
        let T_OPEN_SETTINGS = "PM_WIN/OPEN_SETTINGS"
        let T_STATUS = "PM_WIN/STATUS_LINE"

        var snap = wait_for_render(app, T_OPEN_CONFIRM, 10.0f)
        if (snap == null) {
            panic("{T_OPEN_CONFIRM} never rendered — wrong app running?")
        }
        let p_confirm_btn = widget_center(snap, T_OPEN_CONFIRM)
        let p_settings_btn = widget_center(snap, T_OPEN_SETTINGS)
        let p_status = widget_center(snap, T_STATUS)

        //! Initial cursor placement.
        move_to(app, p_confirm_btn, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate the confirm trigger ----
        move_to(app, p_confirm_btn, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "popup_modal(IDENT, (closable, flags)) — blocking dialog. ImGui dims the parent window and absorbs clicks outside the modal until it closes.",
            target = T_OPEN_CONFIRM,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: open the confirm modal via imgui_open ----
        post_command(app, "imgui_open", JV((target = "PM_WIN/CONFIRM_MODAL")))
        sleep(MODAL_DWELL_MS)
        // Once the modal is up, its CONFIRM_YES button is a registered leaf.
        // Anchor narration there for a stable position over the modal.
        post_command(app, "imgui_narrate", JV((
            text = "imgui_open flips pending_open; next frame the modal opens via OpenPopup. The Yes/No buttons fall through to state.pending_close on click.",
            target = "PM_WIN/CONFIRM_MODAL/CONFIRM_YES",
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: close the confirm modal via Yes-button click ----
        // After the modal is open, CONFIRM_YES is registered.
        var ack_snap = wait_for_render(app, "PM_WIN/CONFIRM_MODAL/CONFIRM_YES", 5.0f)
        if (ack_snap != null) {
            let p_yes = widget_center(ack_snap, "PM_WIN/CONFIRM_MODAL/CONFIRM_YES")
            var yes_events : array<JsonValue?>
            yes_events |> click_at(0, p_yes, 200)
            post_command(app, "imgui_mouse_play", JV((events = yes_events)))
        }
        sleep(MODAL_DWELL_MS)
        move_to(app, p_status, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Modal closed via Yes click — CONFIRM_RESULT updated, modal dismissed. CONFIRM_MODAL.open is back to false.",
            target = T_STATUS,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: settings modal with closable X-button ----
        move_to(app, p_settings_btn, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_open", JV((target = "PM_WIN/SETTINGS_MODAL")))
        sleep(MODAL_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "closable=true adds an X-button on the title bar. ImGui wires it to state.open — click X (or press ESC) to flip open=false and dismiss.",
            target = "PM_WIN/SETTINGS_MODAL/S_AUTOSAVE",
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 5: dismiss via Apply button ----
        var apply_snap = wait_for_render(app, "PM_WIN/SETTINGS_MODAL/S_APPLY", 5.0f)
        if (apply_snap != null) {
            let p_apply = widget_center(apply_snap, "PM_WIN/SETTINGS_MODAL/S_APPLY")
            var apply_events : array<JsonValue?>
            apply_events |> click_at(0, p_apply, 200)
            post_command(app, "imgui_mouse_play", JV((events = apply_events)))
        }
        sleep(MODAL_DWELL_MS)
    }
}
