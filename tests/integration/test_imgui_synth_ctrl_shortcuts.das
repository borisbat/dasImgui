options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

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
def test_imgui_synth_ctrl_shortcuts(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        //! End-to-end: imgui_focus → imgui_key_type "Hi" → expect buffer "Hi".
        //! Same shape as test_key_type_lands_in_input but routed through the
        //! ImGui bypass.
        t |> run("key_type_lands_in_input") <| @(t : T?) {
            var snap0 = wait_for_render(d, "MAIN_WIN/NAME_INPUT", 15.0f)
            t |> success(snap0 != null, "NAME_INPUT renders")
            if (snap0 == null) return

            focus(d, "MAIN_WIN/NAME_INPUT")
            let focused = wait_until(d, 120) $(var snap) {
                return snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["focus"] ?? false
            }
            t |> success(focused != null, "NAME_INPUT receives keyboard focus")

            post_command(d, "imgui_key_type", JV((text = "Hi", per_char_ms = 30)))

            t |> success(wait_for_key_idle(d, 4.0f), "imgui_key_type timeline completes")

            let landed = wait_until(d, 180) $(var snap) {
                let v = snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["payload"]?["value"] ?? ""
                return v == "Hi"
            }
            t |> success(landed != null, "NAME_INPUT.value == \"Hi\" after imgui_key_type")
        }
        reset(d)

        //! Ctrl held via imgui_key_press should show up in the io.key_ctrl
        //! snapshot field. Sanity check that imgui_live's bypass populates
        //! the modifier state (NOT a routing test — that's the next case).
        t |> run("key_chord_ctrl_visible") <| @(t : T?) {
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
        reset(d)

        //! The canary for the click-then-Ctrl+A bug. Synth-clicks NAME_INPUT
        //! to activate it, types text, then select-all → Backspace expects the
        //! buffer to be empty.
        //!
        //! Under the legacy glfw_live driver, the synth click left Shortcut()
        //! routing broken — Ctrl+A no-opped, Backspace deleted only the last
        //! char, and the buffer ended up "ab" instead of "". imgui_live's
        //! bypass purges the backend's queue contribution so NavId is
        //! established correctly at activation.
        //!
        //! Platform note: ImGui sets io.ConfigMacOSXBehaviors=true on macOS
        //! (via #ifdef __APPLE__ in ImGuiIO ctor). When set, the "shortcut key"
        //! is Super (Cmd), not Ctrl — so "select all" is Cmd+A, not Ctrl+A.
        //! We read config_macos_behaviors from the io snapshot and pick the
        //! right modifier accordingly.
        t |> run("click_then_ctrl_a_clears_input") <| @(t : T?) {
            var snap0 = wait_for_render(d, "MAIN_WIN/NAME_INPUT", 15.0f)
            t |> success(snap0 != null, "NAME_INPUT renders")
            if (snap0 == null) return

            // Determine platform shortcut modifier from the io snapshot.
            let macos = snap0?["io"]?["config_macos_behaviors"] ?? false
            let select_all_mod = macos ? "Super" : "Ctrl"

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
            t |> success(wait_for_mouse_idle(d, 4.0f), "imgui_mouse_play synth click completes")

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
            // [PROBE — remove after diagnosis] capture the actual state when this fails on CI:
            // disambiguates activation-race (active_widget != NAME_INPUT) vs keys-lost (val="",
            // timeline drained q=N/N) vs insert-not-replace (val="Name...") vs stall (key_playing,
            // q stuck at 0).
            let dbg_snap = snapshot(d)
            let dbg_val = dbg_snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["payload"]?["value"] ?? "?"
            let dbg_aw = dbg_snap?["io"]?["active_widget"] ?? "none"
            let dbg_focus = dbg_snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["focus"] ?? false
            let dbg_ks = post_command(d, "imgui_key_status", null)
            let dbg_kp = dbg_ks?["playing"] ?? true
            let dbg_qi = dbg_ks?["queue_idx"] ?? -1
            let dbg_qt = dbg_ks?["queue_total"] ?? -1
            t |> success(typed != null, "NAME_INPUT.value == \"abc\" before chord [val='{dbg_val}' active_widget={dbg_aw} focus={dbg_focus} key_playing={dbg_kp} q={dbg_qi}/{dbg_qt}]")

            // The value showing "abc" proves the chars landed, but the key_type
            // timeline's final per-char delay may still be ticking; let it reach
            // idle before the chord so the chord events don't interleave its tail.
            t |> success(wait_for_key_idle(d, 4.0f), "key_type timeline idle before chord")

            // Select-all chord: Cmd+A on macOS, Ctrl+A everywhere else.
            if (macos) {
                post_command(d, "imgui_key_chord", JV((mods = ["Super"], key = "A")))
            } else {
                post_command(d, "imgui_key_chord", JV((mods = ["Ctrl"], key = "A")))
            }
            t |> success(wait_for_key_idle(d, 4.0f), "{select_all_mod}+A chord completes")

            // Backspace once → if selection is active, buffer empties.
            let bksp = int(ImGuiKey.Backspace)
            post_command(d, "imgui_key_press",   JV((key = bksp)))
            post_command(d, "imgui_key_release", JV((key = bksp)))

            let emptied = wait_until(d, 240) $(var snap) {
                let v = snap?["globals"]?["MAIN_WIN/NAME_INPUT"]?["payload"]?["value"] ?? "still-has-content"
                return v == ""
            }
            t |> success(emptied != null, "NAME_INPUT.value == \"\" after {select_all_mod}+A then Backspace")
        }
    }
}
