options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public
require math

//! ImGui-bypass synth driver — Ctrl-shortcut routing after a synth click.
//!
//! Regression coverage for the bug at memory
//! project_imgui_synth_click_breaks_ctrl_shortcuts: under the legacy
//! glfw_live chain dispatch, any synth mouse click into an InputText
//! left ImGui's Shortcut() routing broken for the rest of the session —
//! Ctrl+A / Ctrl+Backspace silently no-opped. The imgui_live driver
//! erases backend events from g.InputEventsQueue before NewFrame drains,
//! so click activation no longer poisons the routing path.
//!
//! Shares the feature app with `test_glfw_synth_keys.das` — both render
//! NAME_INPUT, and the feature's per-frame `apply_synth_io_override()`
//! call now drives both glfw_live and imgui_live tick paths.

let FEATURE = "modules/dasImgui/examples/features/glfw_synth_keys.das"

[test]
def test_imgui_key_type_lands_in_input(t : T?) {
    //! End-to-end: imgui_focus → imgui_key_type "Hi" → expect buffer "Hi".
    //! Same shape as test_key_type_lands_in_input but routed through the
    //! ImGui bypass.
    with_imgui_app(FEATURE) $(d) {
        var snap0 = wait_for_render(d, "MAIN_WIN/NAME_INPUT", 15.0f)
        t |> success(snap0 != null, "NAME_INPUT renders")
        if (snap0 == null) return

        focus(d, "MAIN_WIN/NAME_INPUT")
        let focused = wait_until(d, 120) $(var snap) {
            return snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["focus"] ?? false
        }
        t |> success(focused != null, "NAME_INPUT receives keyboard focus")

        post_command(d, "imgui_key_type", JV((text = "Hi", per_char_ms = 30)))

        let done = wait_until(d, 240) $(var snap) {
            let s = post_command(d, "imgui_key_status", null)
            return !(s?["playing"] ?? true)
        }
        t |> success(done != null, "imgui_key_type timeline completes")

        let landed = wait_until(d, 180) $(var snap) {
            let v = snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["payload"]?["value"] ?? ""
            return v == "Hi"
        }
        t |> success(landed != null, "NAME_INPUT.value == \"Hi\" after imgui_key_type")
    }
}

[test]
def test_imgui_key_chord_ctrl_visible(t : T?) {
    //! Ctrl held via imgui_key_press should show up in the io.key_ctrl
    //! snapshot field. Sanity check that imgui_live's bypass populates
    //! the modifier state (NOT a routing test — that's the next case).
    with_imgui_app(FEATURE) $(d) {
        var snap0 = wait_for_render(d, "MAIN_WIN/NAME_INPUT", 15.0f)
        t |> success(snap0 != null, "NAME_INPUT renders")
        if (snap0 == null) return

        let ctrl_key = int(ImGuiKey.LeftCtrl)
        post_command(d, "imgui_key_press", JV((key = ctrl_key)))
        let saw_ctrl = wait_until(d, 240) $(var snap) {
            return snap?["io"]?["key_ctrl"] ?? false
        }
        t |> success(saw_ctrl != null, "io.key_ctrl == true while synth Ctrl held via imgui_live")
        post_command(d, "imgui_key_release", JV((key = ctrl_key)))
        let cleared = wait_until(d, 240) $(var snap) {
            return !(snap?["io"]?["key_ctrl"] ?? true)
        }
        t |> success(cleared != null, "io.key_ctrl == false after release")
    }
}

[test]
def test_click_then_ctrl_a_clears_input(t : T?) {
    //! The canary for the click-then-Ctrl+A bug. Synth-clicks NAME_INPUT
    //! to activate it, types text, then Ctrl+A → Backspace expects the
    //! buffer to be empty.
    //!
    //! Under the legacy glfw_live driver, the synth click left Shortcut()
    //! routing broken — Ctrl+A no-opped, Backspace deleted only the last
    //! char, and the buffer ended up "ab" instead of "". imgui_live's
    //! bypass purges the backend's queue contribution so NavId is
    //! established correctly at activation.
    with_imgui_app(FEATURE) $(d) {
        var snap0 = wait_for_render(d, "MAIN_WIN/NAME_INPUT", 15.0f)
        t |> success(snap0 != null, "NAME_INPUT renders")
        if (snap0 == null) return

        // Locate NAME_INPUT center for the synth click.
        let b = snap0?["globals"]?["MAIN_WIN/NAME_INPUT"]?["bbox"]
        let cx = ((b?["x"] ?? 0.0f) + (b?["z"] ?? 0.0f)) * 0.5f
        let cy = ((b?["y"] ?? 0.0f) + (b?["w"] ?? 0.0f)) * 0.5f
        var click_events <- [
            JV((t_ms = 0,   kind = "move",   x = cx, y = cy)),
            JV((t_ms = 50,  kind = "button", button = 0, action = "press")),
            JV((t_ms = 100, kind = "button", button = 0, action = "release"))
        ]
        post_command(d, "imgui_mouse_play", JV((events = click_events)))
        let clicked = wait_until(d, 240) $(var snap) {
            let s = post_command(d, "imgui_mouse_status", null)
            return !(s?["playing"] ?? true)
        }
        t |> success(clicked != null, "imgui_mouse_play synth click completes")

        let activated = wait_until(d, 240) $(var snap) {
            return snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["focus"] ?? false
        }
        t |> success(activated != null, "NAME_INPUT becomes focused after synth click")

        // Type "abc".
        post_command(d, "imgui_key_type", JV((text = "abc", per_char_ms = 30)))
        let typed = wait_until(d, 240) $(var snap) {
            let v = snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["payload"]?["value"] ?? ""
            return v == "abc"
        }
        t |> success(typed != null, "NAME_INPUT.value == \"abc\" before chord")

        // Ctrl+A to select-all (the formerly-broken shortcut).
        post_command(d, "imgui_key_chord", JV((mods = ["Ctrl"], key = "A")))
        let chord_done = wait_until(d, 240) $(var snap) {
            let s = post_command(d, "imgui_key_status", null)
            return !(s?["playing"] ?? true)
        }
        t |> success(chord_done != null, "Ctrl+A chord completes")

        // Backspace once → if selection is active, buffer empties.
        let bksp = int(ImGuiKey.Backspace)
        post_command(d, "imgui_key_press",   JV((key = bksp)))
        post_command(d, "imgui_key_release", JV((key = bksp)))

        let emptied = wait_until(d, 240) $(var snap) {
            let v = snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["payload"]?["value"] ?? "still-has-content"
            return v == ""
        }
        t |> success(emptied != null, "NAME_INPUT.value == \"\" after Ctrl+A then Backspace")
    }
}
