options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui public
require imgui/imgui_playwright public
require daslib/clipboard public
require daslib/json public
require daslib/json_boost public

//! Deterministic interaction coverage for the Markdown viewer.
//!
//! The body never waits for elapsed time or a number of frames.  Every input
//! is followed by a semantic acknowledgement from the running application:
//! hover identity, selection/copy/context revisions, popup state, or observed
//! scroll.
//! `wait_cond`'s limit is only a deadlock/crash guard.

let FEATURE = "modules/dasImgui/examples/features/markdown_viewer.das"
let DEADLOCK_GUARD_SEC = 30.0f

def private markdown_state(app : ImguiApp) : JsonValue? {
    return post_command(app, "markdown_probe_state", null)
}

def private markdown_fragment(app : ImguiApp; text : string) : JsonValue? {
    return post_command(app, "markdown_probe_fragment", JV((text = text)))
}

def private same_rect(var a : JsonValue?; var b : JsonValue?) : bool {
    return ((a?["x0"] ?? -1.0f) == (b?["x0"] ?? -2.0f)
        && (a?["y0"] ?? -1.0f) == (b?["y0"] ?? -2.0f)
        && (a?["x1"] ?? -1.0f) == (b?["x1"] ?? -2.0f)
        && (a?["y1"] ?? -1.0f) == (b?["y1"] ?? -2.0f))
}

[test]
def test_markdown_view_event_driven_interactions(t : T?) {
    with_imgui_app(FEATURE) $(app) {
        // Application readiness is the first rendered Markdown revision, not
        // a boot delay and not a frame count.
        var ready_state : JsonValue?
        let ready = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            ready_state = markdown_state(app)
            return ((ready_state?["ok"] ?? false)
                && (ready_state?["render_revision"] ?? 0) > 0)
        }
        t |> success(ready, "Markdown live probe reaches a rendered revision")
        if (!ready) return

        // The copy-URI affordance appears on hover, but its reserved control
        // slot must not resize or move the link text.
        var link_before : JsonValue?
        let found_link = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            link_before = markdown_fragment(app, "documentation")
            return link_before?["ok"] ?? false
        }
        t |> success(found_link, "documentation link fragment is inspectable")
        if (!found_link) return
        let link_node = link_before?["node"] ?? -1
        let link_fragment = link_before?["fragment"] ?? -1
        let link_x = ((link_before?["x0"] ?? 0.0f)
            + (link_before?["x1"] ?? 0.0f)) * 0.5f
        let link_y = ((link_before?["y0"] ?? 0.0f)
            + (link_before?["y1"] ?? 0.0f)) * 0.5f
        post_command(app, "imgui_mouse_pos", JV((x = link_x, y = link_y)))
        let link_hovered = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return ((state?["hovered_inline_node"] ?? -1) == link_node
                && (state?["hovered_fragment"] ?? -1) == link_fragment)
        }
        t |> success(link_hovered, "mouse move is acknowledged by link hover identity")
        var link_after = markdown_fragment(app, "documentation")
        t |> success((link_after?["ok"] ?? false) && same_rect(link_before, link_after),
                     "URI hover leaves fragment geometry unchanged")

        // Select inline code with a strict event/state handshake:
        // move -> hover, press -> dragging revision, move -> focus revision,
        // release -> committed revision.
        var code : JsonValue?
        let found_code = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            code = markdown_fragment(app, "inline code")
            return code?["ok"] ?? false
        }
        t |> success(found_code, "inline-code fragment is inspectable")
        if (!found_code) return
        let code_node = code?["node"] ?? -1
        let code_fragment = code?["fragment"] ?? -1
        let code_x0 = (code?["x0"] ?? 0.0f) + 2.0f
        let code_x1 = (code?["x1"] ?? 0.0f) - 2.0f
        let code_y = ((code?["y0"] ?? 0.0f) + (code?["y1"] ?? 0.0f)) * 0.5f

        post_command(app, "imgui_mouse_pos", JV((x = code_x0, y = code_y)))
        let code_hovered = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return ((state?["hovered_inline_node"] ?? -1) == code_node
                && (state?["hovered_fragment"] ?? -1) == code_fragment)
        }
        t |> success(code_hovered, "selection start is acknowledged as hovered")
        if (!code_hovered) return

        var before_press = markdown_state(app)
        let revision_before_press = before_press?["selection"]?["revision"] ?? -1
        post_command(app, "imgui_mouse_click", JV((button = 0, action = "press")))
        var pressed_state : JsonValue?
        let pressed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            pressed_state = markdown_state(app)
            return ((pressed_state?["selection"]?["dragging"] ?? false)
                && (pressed_state?["selection"]?["revision"] ?? -1)
                    > revision_before_press)
        }
        t |> success(pressed, "left press starts selection and advances its revision")
        if (!pressed) return

        let revision_after_press = pressed_state?["selection"]?["revision"] ?? -1
        post_command(app, "imgui_mouse_pos", JV((x = code_x1, y = code_y)))
        var dragged_state : JsonValue?
        let dragged = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            dragged_state = markdown_state(app)
            return ((dragged_state?["selection"]?["dragging"] ?? false)
                && (dragged_state?["selection"]?["revision"] ?? -1)
                    > revision_after_press
                && (dragged_state?["selection"]?["active"] ?? false))
        }
        t |> success(dragged, "mouse move advances selection focus and source range")
        if (!dragged) return

        let commit_before = dragged_state?["selection"]?["commit_revision"] ?? -1
        post_command(app, "imgui_mouse_click", JV((button = 0, action = "release")))
        var committed_state : JsonValue?
        let committed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            committed_state = markdown_state(app)
            return (!(committed_state?["selection"]?["dragging"] ?? true)
                && (committed_state?["selection"]?["commit_revision"] ?? -1)
                    > commit_before)
        }
        t |> success(committed, "left release commits selection")
        if (!committed) return
        t |> success(committed_state?["selection"]?["active"] ?? false,
                     "committed code selection is active")
        t |> success(committed_state?["selection"]?["has_code"] ?? false,
                     "committed selection reports code style")
        t |> success((committed_state?["selection"]?["source_end"] ?? -1)
                        > (committed_state?["selection"]?["source_start"] ?? -1),
                     "committed selection maps to a non-empty original source range")
        t |> success(committed_state?["selection"]?["screen_valid"] ?? false,
                     "committed selection exposes its screen anchor geometry")

        // Copy is also a raw key/state handshake.  Preserve the user's
        // clipboard and run this branch only when the current desktop session
        // actually provides readable/writable text clipboard access.
        var original_clipboard = ""
        let original_clipboard_status = clipboard_get_text(original_clipboard)
        let clipboard_available = (clipboard_set_text("dasImgui clipboard probe")
            == ClipboardStatus.ok)
        if (clipboard_available) {
            let selected_text = committed_state?["selection"]?["display_text"] ?? ""
            let copy_before = committed_state?["selection"]?["copy_revision"] ?? -1
            var input_state = markdown_state(app)
            let macos = input_state?["input"]?["macos_behaviors"] ?? false
            // ImGui remaps synthetic LeftCtrl to Super when macOS behaviors
            // are enabled, matching the viewer's platform shortcut choice.
            let copy_modifier_key = int(ImGuiKey.LeftCtrl)
            post_command(app, "imgui_key_press", JV((key = copy_modifier_key)))
            let modifier_down = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
                var state = markdown_state(app)
                return state?["input"]?["copy_modifier_down"] ?? false
            }
            t |> success(modifier_down,
                         macos ? "synthetic Cmd modifier is observed"
                               : "synthetic Ctrl modifier is observed")

            post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.C))))
            var copied_text = ""
            let copied = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
                var state = markdown_state(app)
                let copied_revision = state?["selection"]?["copy_revision"] ?? -1
                let clipboard_status = clipboard_get_text(copied_text)
                return (copied_revision > copy_before
                    && clipboard_status == ClipboardStatus.ok
                    && copied_text == selected_text)
            }
            t |> success(copied,
                         "Ctrl/Cmd+C revision and system clipboard match selected display text")

            post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.C))))
            let c_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
                var state = markdown_state(app)
                return !(state?["input"]?["key_c_down"] ?? true)
            }
            t |> success(c_released, "C release is observed")
            post_command(app, "imgui_key_release", JV((key = copy_modifier_key)))
            let modifier_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
                var state = markdown_state(app)
                return !(state?["input"]?["copy_modifier_down"] ?? true)
            }
            t |> success(modifier_released, "copy modifier release is observed")

            if (original_clipboard_status == ClipboardStatus.ok) {
                let _ = clipboard_set_text(original_clipboard)
            } else {
                let _ = clipboard_clear()
            }
        } else {
            t |> success(true,
                         "system clipboard unavailable in this desktop session; explicit platform result accepted")
        }

        // Right-click the single-line selection.  Button-down, context event,
        // popup visibility, and Escape close are each observed before the next
        // input is sent.
        let selection_x = ((committed_state?["selection"]?["screen_x0"] ?? 0.0f)
            + (committed_state?["selection"]?["screen_x1"] ?? 0.0f)) * 0.5f
        let selection_y = ((committed_state?["selection"]?["screen_y0"] ?? 0.0f)
            + (committed_state?["selection"]?["screen_y1"] ?? 0.0f)) * 0.5f
        post_command(app, "imgui_mouse_pos", JV((x = selection_x, y = selection_y)))
        let selection_hovered = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return ((state?["hovered_inline_node"] ?? -1) == code_node
                && (state?["hovered_fragment"] ?? -1) == code_fragment)
        }
        t |> success(selection_hovered,
                     "context target is acknowledged as the selected fragment")

        var context_before_state = markdown_state(app)
        let context_before = context_before_state?["selection"]?["context_revision"] ?? -1
        post_command(app, "imgui_mouse_click", JV((button = 1, action = "press")))
        let right_down = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return state?["input"]?["right_down"] ?? false
        }
        t |> success(right_down, "right press is observed")
        post_command(app, "imgui_mouse_click", JV((button = 1, action = "release")))
        var context_state : JsonValue?
        let context_requested = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            context_state = markdown_state(app)
            return (!(context_state?["input"]?["right_down"] ?? true)
                && (context_state?["selection"]?["context_revision"] ?? -1)
                    > context_before)
        }
        t |> success(context_requested,
                     "right release advances the selection context revision")
        t |> equal(context_state?["context_source_start"] ?? -1,
                   committed_state?["selection"]?["source_start"] ?? -2,
                   "comment anchor starts at the selected original source byte")
        t |> equal(context_state?["context_source_end"] ?? -1,
                   committed_state?["selection"]?["source_end"] ?? -2,
                   "comment anchor ends at the selected original source byte")

        var popup_snap : JsonValue?
        let popup_open = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            popup_snap = snapshot(app)
            return widget_rendered(popup_snap,
                                   "MARKDOWN_VIEW_WIN/SELECTION_COMMENT_POPUP/ADD_COMMENT")
        }
        t |> success(popup_open, "comment popup visibility is observed")
        if (!popup_open) return
        let add_comment = find_widget(popup_snap,
            "MARKDOWN_VIEW_WIN/SELECTION_COMMENT_POPUP/ADD_COMMENT")
        let add_x = ((add_comment?["bbox"]?["x"] ?? 0.0f)
            + (add_comment?["bbox"]?["z"] ?? 0.0f)) * 0.5f
        let add_y = ((add_comment?["bbox"]?["y"] ?? 0.0f)
            + (add_comment?["bbox"]?["w"] ?? 0.0f)) * 0.5f
        post_command(app, "imgui_mouse_pos", JV((x = add_x, y = add_y)))
        let add_targeted = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return state?["add_comment_hovered"] ?? false
        }
        t |> success(add_targeted, "Add comment button hover is observed")
        post_command(app, "imgui_mouse_click", JV((button = 0, action = "press")))
        let add_pressed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var snap = snapshot(app)
            return snap?["io"]?["mouse_buttons"]?[0] ?? false
        }
        t |> success(add_pressed, "Add comment button press is observed")
        post_command(app, "imgui_mouse_click", JV((button = 0, action = "release")))
        let popup_closed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var snap = snapshot(app)
            return (!(snap?["io"]?["mouse_buttons"]?[0] ?? true)
                && !widget_rendered(snap,
                    "MARKDOWN_VIEW_WIN/SELECTION_COMMENT_POPUP/ADD_COMMENT"))
        }
        t |> success(popup_closed,
                     "Add comment release and closed popup are observed")

        // Clear has its own acknowledgement, then one raw wheel event must be
        // observed as a changed ImGui window scroll value.
        let clear_result = post_command(app, "markdown_probe_clear_selection", null)
        let clear_revision = clear_result?["selection_revision"] ?? -1
        let cleared = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return (!(state?["selection"]?["active"] ?? true)
                && (state?["selection"]?["revision"] ?? -1) >= clear_revision)
        }
        t |> success(cleared, "selection clear is acknowledged")

        // A plain click leaves a collapsed, screen-visible caret.  Horizontal
        // arrows move it by grapheme; Shift+Right extends the same anchor into
        // a source-mapped selection. Every key press and release is observed.
        let caret_x = (code_x0 + code_x1) * 0.5f
        post_command(app, "imgui_mouse_pos", JV((x = caret_x, y = code_y)))
        let caret_targeted = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return ((state?["hovered_inline_node"] ?? -1) == code_node
                && (state?["hovered_fragment"] ?? -1) == code_fragment)
        }
        t |> success(caret_targeted, "caret click target is acknowledged")
        var caret_before_click = markdown_state(app)
        let caret_commit_before = caret_before_click?["selection"]?["commit_revision"] ?? -1
        post_command(app, "imgui_mouse_click", JV((button = 0, action = "press")))
        let caret_pressed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return state?["selection"]?["dragging"] ?? false
        }
        t |> success(caret_pressed, "collapsed caret press is observed")
        post_command(app, "imgui_mouse_click", JV((button = 0, action = "release")))
        var caret_state : JsonValue?
        let caret_placed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            caret_state = markdown_state(app)
            return (!(caret_state?["selection"]?["dragging"] ?? true)
                && (caret_state?["selection"]?["commit_revision"] ?? -1)
                    > caret_commit_before
                && (caret_state?["caret"]?["valid"] ?? false)
                && !(caret_state?["selection"]?["active"] ?? true))
        }
        t |> success(caret_placed, "plain click commits a visible collapsed caret")
        if (!caret_placed) return

        let caret_display_before = caret_state?["caret"]?["display_byte"] ?? -1
        let navigation_before = caret_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.RightArrow))))
        var moved_caret_state : JsonValue?
        let moved_right = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            moved_caret_state = markdown_state(app)
            return ((moved_caret_state?["input"]?["right_arrow_down"] ?? false)
                && (moved_caret_state?["selection"]?["navigation_revision"] ?? -1)
                    > navigation_before
                && (moved_caret_state?["caret"]?["display_byte"] ?? -1)
                    > caret_display_before)
        }
        t |> success(moved_right, "Right Arrow advances the caret by one grapheme")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.RightArrow))))
        let right_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["right_arrow_down"] ?? true)
        }
        t |> success(right_released, "Right Arrow release is observed")

        let shifted_anchor_source = moved_caret_state?["caret"]?["source_byte"] ?? -1
        let shift_navigation_before = moved_caret_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.LeftShift))))
        let shift_pressed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return state?["input"]?["shift_down"] ?? false
        }
        t |> success(shift_pressed, "Shift press is observed")
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.RightArrow))))
        var shifted_state : JsonValue?
        let shifted_right = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            shifted_state = markdown_state(app)
            return ((shifted_state?["input"]?["right_arrow_down"] ?? false)
                && (shifted_state?["selection"]?["navigation_revision"] ?? -1)
                    > shift_navigation_before
                && (shifted_state?["selection"]?["active"] ?? false))
        }
        t |> success(shifted_right, "Shift+Right extends a source-mapped selection")
        t |> equal(shifted_state?["selection"]?["source_start"] ?? -1,
                   shifted_anchor_source,
                   "Shift selection starts at the original caret source byte")
        t |> success(shifted_state?["selection"]?["has_code"] ?? false,
                     "keyboard-extended selection retains code style")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.RightArrow))))
        let shifted_right_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["right_arrow_down"] ?? true)
        }
        t |> success(shifted_right_released, "shifted Right Arrow release is observed")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.LeftShift))))
        let shift_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["shift_down"] ?? true)
        }
        t |> success(shift_released, "Shift release is observed")

        let left_navigation_before = shifted_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.LeftArrow))))
        var collapsed_left_state : JsonValue?
        let collapsed_left = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            collapsed_left_state = markdown_state(app)
            return ((collapsed_left_state?["input"]?["left_down"] ?? false)
                && (collapsed_left_state?["selection"]?["navigation_revision"] ?? -1)
                    > left_navigation_before
                && !(collapsed_left_state?["selection"]?["active"] ?? true)
                && (collapsed_left_state?["caret"]?["source_byte"] ?? -1)
                    == shifted_anchor_source)
        }
        t |> success(collapsed_left,
                     "Left Arrow collapses selection to its leading caret")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.LeftArrow))))
        let left_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["left_down"] ?? true)
        }
        t |> success(left_released, "Left Arrow release is observed")

        let home_navigation_before = collapsed_left_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.Home))))
        var home_state : JsonValue?
        let moved_home = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            home_state = markdown_state(app)
            return ((home_state?["input"]?["home_down"] ?? false)
                && (home_state?["selection"]?["navigation_revision"] ?? -1)
                    > home_navigation_before
                && (home_state?["caret"]?["display_byte"] ?? -1)
                    < (collapsed_left_state?["caret"]?["display_byte"] ?? -1))
        }
        t |> success(moved_home, "Home moves to the visual-line start")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.Home))))
        let home_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["home_down"] ?? true)
        }
        t |> success(home_released, "Home release is observed")

        let end_navigation_before = home_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.End))))
        var end_state : JsonValue?
        let moved_end = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            end_state = markdown_state(app)
            return ((end_state?["input"]?["end_down"] ?? false)
                && (end_state?["selection"]?["navigation_revision"] ?? -1)
                    > end_navigation_before
                && (end_state?["caret"]?["display_byte"] ?? -1)
                    > (home_state?["caret"]?["display_byte"] ?? -1))
        }
        t |> success(moved_end, "End moves to the visual-line end")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.End))))
        let end_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["end_down"] ?? true)
        }
        t |> success(end_released, "End release is observed")

        let end_y = end_state?["caret"]?["y"] ?? -1.0f
        let up_navigation_before = end_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.UpArrow))))
        var up_state : JsonValue?
        let moved_up = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            up_state = markdown_state(app)
            return ((up_state?["input"]?["up_down"] ?? false)
                && (up_state?["selection"]?["navigation_revision"] ?? -1)
                    > up_navigation_before
                && (up_state?["caret"]?["y"] ?? end_y) < end_y)
        }
        t |> success(moved_up, "Up Arrow moves to the preceding visual line")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.UpArrow))))
        let up_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["up_down"] ?? true)
        }
        t |> success(up_released, "Up Arrow release is observed")

        let up_y = up_state?["caret"]?["y"] ?? 1000000.0f
        let down_navigation_before = up_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.DownArrow))))
        var down_state : JsonValue?
        let moved_down = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            down_state = markdown_state(app)
            return ((down_state?["input"]?["down_down"] ?? false)
                && (down_state?["selection"]?["navigation_revision"] ?? -1)
                    > down_navigation_before
                && (down_state?["caret"]?["y"] ?? up_y) > up_y)
        }
        t |> success(moved_down,
                     "Down Arrow moves to the following visual line")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.DownArrow))))
        let down_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["down_down"] ?? true)
        }
        t |> success(down_released, "Down Arrow release is observed")

        let vertical_anchor_source = down_state?["caret"]?["source_byte"] ?? -1
        let shift_down_navigation_before = down_state?["selection"]?["navigation_revision"] ?? -1
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.LeftShift))))
        let vertical_shift_pressed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return state?["input"]?["shift_down"] ?? false
        }
        t |> success(vertical_shift_pressed, "vertical Shift press is observed")
        post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.DownArrow))))
        var shifted_down_state : JsonValue?
        let shifted_down = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            shifted_down_state = markdown_state(app)
            return ((shifted_down_state?["input"]?["down_down"] ?? false)
                && (shifted_down_state?["selection"]?["navigation_revision"] ?? -1)
                    > shift_down_navigation_before
                && (shifted_down_state?["selection"]?["active"] ?? false))
        }
        t |> success(shifted_down,
                     "Shift+Down extends selection to the following visual line")
        t |> equal(shifted_down_state?["selection"]?["source_start"] ?? -1,
                   vertical_anchor_source,
                   "vertical selection retains its original source anchor")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.DownArrow))))
        let shifted_down_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["down_down"] ?? true)
        }
        t |> success(shifted_down_released, "shifted Down Arrow release is observed")
        post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.LeftShift))))
        let vertical_shift_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return !(state?["input"]?["shift_down"] ?? true)
        }
        t |> success(vertical_shift_released, "vertical Shift release is observed")

        let zoom_result = post_command(app, "markdown_probe_set_zoom",
                                       JV((percent = 200)))
        let zoom_prior_render = zoom_result?["prior_render_revision"] ?? -1
        let zoom_rendered = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var state = markdown_state(app)
            return ((state?["zoom_percent"] ?? 0) == 200
                && (state?["render_revision"] ?? -1) > zoom_prior_render)
        }
        t |> success(zoom_rendered,
                     "200% zoom is acknowledged by a later rendered revision")
        if (!zoom_rendered) return

        var scroll_before = 0.0f
        var scroll_ready = false
        let got_scroll = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var snap = snapshot(app)
            var scroll = widget_payload_field(snap, "MARKDOWN_VIEW_WIN", "scroll")
            var scroll_max = widget_payload_field(snap, "MARKDOWN_VIEW_WIN", "scroll_max")
            scroll_ready = scroll != null && (scroll_max?["y"] ?? 0.0f) > 0.0f
            if (scroll_ready) {
                scroll_before = scroll?["y"] ?? 0.0f
            }
            return scroll_ready
        }
        t |> success(got_scroll, "Markdown window reports scrollable content")
        if (!got_scroll) return

        var auto_state = markdown_state(app)
        let auto_scroll_before = auto_state?["selection"]?["navigation_scroll_revision"] ?? -1
        var auto_scrolled = false
        for (_step in range(48)) {
            break if (auto_scrolled)
            let step_navigation_before = auto_state?["selection"]?["navigation_revision"] ?? -1
            post_command(app, "imgui_key_press", JV((key = int(ImGuiKey.DownArrow))))
            let step_moved = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
                auto_state = markdown_state(app)
                return ((auto_state?["input"]?["down_down"] ?? false)
                    && (auto_state?["selection"]?["navigation_revision"] ?? -1)
                        > step_navigation_before)
            }
            t |> success(step_moved,
                         "autoscroll navigation step receives a semantic acknowledgement")
            if (!step_moved) return
            post_command(app, "imgui_key_release", JV((key = int(ImGuiKey.DownArrow))))
            let step_released = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
                var state = markdown_state(app)
                return !(state?["input"]?["down_down"] ?? true)
            }
            t |> success(step_released,
                         "autoscroll navigation key release is observed")
            auto_state = markdown_state(app)
            auto_scrolled = ((auto_state?["selection"]?["navigation_scroll_revision"] ?? -1)
                > auto_scroll_before)
        }
        t |> success(auto_scrolled,
                     "vertical keyboard navigation requests scroll when caret leaves viewport")
        if (!auto_scrolled) return
        let auto_scroll_observed = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var snap = snapshot(app)
            var scroll = widget_payload_field(snap, "MARKDOWN_VIEW_WIN", "scroll")
            return (scroll?["y"] ?? scroll_before) > scroll_before
        }
        t |> success(auto_scroll_observed,
                     "keyboard autoscroll changes the registered window scroll state")
        var after_auto_snap = snapshot(app)
        var after_auto_scroll = widget_payload_field(after_auto_snap,
            "MARKDOWN_VIEW_WIN", "scroll")
        scroll_before = after_auto_scroll?["y"] ?? scroll_before
        post_command(app, "imgui_mouse_scroll", JV((x = 0.0f, y = -4.0f)))
        let scrolled = wait_cond(app, DEADLOCK_GUARD_SEC) $() : bool {
            var snap = snapshot(app)
            var scroll = widget_payload_field(snap, "MARKDOWN_VIEW_WIN", "scroll")
            return (scroll?["y"] ?? scroll_before) > scroll_before
        }
        t |> success(scrolled, "wheel event is acknowledged by changed scroll state")
    }
}
