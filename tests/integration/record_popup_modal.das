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
//! (non-closable) and the X-button settings modal — driving all three
//! interactive widgets inside Settings (S_AUTOSAVE, S_TELEMETRY,
//! S_MAX_FPS) so the audit's "modal widgets visible but never driven"
//! gap is closed.

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
                       "popup_modal.apng", 80) $(app) {
        // window/popup_modal containers finalize without a bbox — anchor
        // every cursor + narration target at a button or text leaf. See
        // PR #67 Copilot round 1.
        let T_OPEN_CONFIRM = "PM_WIN/OPEN_CONFIRM"
        let T_OPEN_SETTINGS = "PM_WIN/OPEN_SETTINGS"
        let T_STATUS = "PM_WIN/STATUS_LINE"
        let T_S_AUTOSAVE = "PM_WIN/SETTINGS_MODAL/S_AUTOSAVE"
        let T_S_TELEMETRY = "PM_WIN/SETTINGS_MODAL/S_TELEMETRY"
        let T_S_MAX_FPS = "PM_WIN/SETTINGS_MODAL/S_MAX_FPS"
        let T_S_APPLY = "PM_WIN/SETTINGS_MODAL/S_APPLY"
        let T_CONFIRM_YES = "PM_WIN/CONFIRM_MODAL/CONFIRM_YES"

        // wait_for_widget gates on existence; wait_for_render passes
        // through for absent paths.
        var snap = wait_for_widget(app, T_OPEN_CONFIRM, 10.0f)
        if (snap == null) {
            panic("{T_OPEN_CONFIRM} never registered — wrong app running?")
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
        say(app, "popup_modal(IDENT, (closable, flags)) — blocking dialog. ImGui dims the parent window and absorbs clicks outside the modal until it closes.", T_OPEN_CONFIRM)

        // ---- Stage 2: open the confirm modal via imgui_open ----
        post_command(app, "imgui_open", JV((target = "PM_WIN/CONFIRM_MODAL")))
        sleep(MODAL_DWELL_MS)
        // Gate narration on CONFIRM_YES actually being registered — otherwise
        // a slow modal open silently lands the overlay at (0,0).
        var ack_snap = wait_for_widget(app, T_CONFIRM_YES, 5.0f)
        if (ack_snap == null) {
            panic("{T_CONFIRM_YES} never registered — imgui_open didn't take")
        }
        say(app, "imgui_open flips pending_open; next frame the modal opens via OpenPopup. The Yes/No buttons fall through to state.pending_close on click.", T_CONFIRM_YES)

        // ---- Stage 3: close the confirm modal via Yes-button click ----
        let p_yes = widget_center(ack_snap, T_CONFIRM_YES)
        var yes_events : array<JsonValue?>
        yes_events |> click_at(0, p_yes, 200)
        post_command(app, "imgui_mouse_play", JV((events = yes_events)))
        sleep(MODAL_DWELL_MS)
        move_to(app, p_status, 700)
        sleep(SETTLE_MS)
        say(app, "Modal closed via Yes click — CONFIRM_RESULT updated, modal dismissed. CONFIRM_MODAL.open is back to false.", T_STATUS)

        // ---- Stage 4: open settings modal with closable X-button ----
        move_to(app, p_settings_btn, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_open", JV((target = "PM_WIN/SETTINGS_MODAL")))
        sleep(MODAL_DWELL_MS)
        var settings_snap = wait_for_widget(app, T_S_APPLY, 5.0f)
        if (settings_snap == null) {
            panic("{T_S_APPLY} never registered — imgui_open didn't take")
        }
        let p_autosave = widget_center(settings_snap, T_S_AUTOSAVE)
        let p_telemetry = widget_center(settings_snap, T_S_TELEMETRY)
        let p_max_fps = widget_center(settings_snap, T_S_MAX_FPS)
        say(app, "Settings modal — closable=true wires the title-bar X-button to state.open. Try the X (or ESC) live; here we'll drive the body widgets and dismiss via Apply.", T_S_AUTOSAVE)

        // ---- Stage 5: drive S_AUTOSAVE checkbox ----
        move_to(app, p_autosave)
        sleep(SETTLE_MS)
        click(app, T_S_AUTOSAVE)
        sleep(CLICK_DWELL_MS)
        say(app, "S_AUTOSAVE toggled inside the modal — its dispatcher routes the click through state.pending_value just like any non-modal checkbox.", T_S_AUTOSAVE)

        // ---- Stage 6: drive S_TELEMETRY checkbox ----
        move_to(app, p_telemetry)
        sleep(SETTLE_MS)
        click(app, T_S_TELEMETRY)
        sleep(CLICK_DWELL_MS)
        say(app, "S_TELEMETRY toggled — modals don't change widget addressing; path push works through popup_modal exactly like through window.", T_S_TELEMETRY)

        // ---- Stage 7: drive S_MAX_FPS slider ----
        move_to(app, p_max_fps)
        sleep(SETTLE_MS)
        set_value(app, T_S_MAX_FPS, JV(90))
        sleep(CLICK_DWELL_MS)
        say(app, "S_MAX_FPS set to 90 via imgui_set — the slider lives inside the modal body, addressed via PM_WIN/SETTINGS_MODAL/S_MAX_FPS.", T_S_MAX_FPS)

        // ---- Stage 8: dismiss via Apply button ----
        let p_apply = widget_center(settings_snap, T_S_APPLY)
        var apply_events : array<JsonValue?>
        apply_events |> click_at(0, p_apply, 200)
        post_command(app, "imgui_mouse_play", JV((events = apply_events)))
        sleep(MODAL_DWELL_MS)
    }
}
