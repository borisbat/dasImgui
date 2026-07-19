options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public
require daslib/strings_boost

let TERMINAL_FEATURE = "modules/dasImgui/examples/features/embedded_terminal.das"
let TERMINAL_TARGET = "TERMINAL_WIN/shell"
let TERMINAL_FOCUS = "TERMINAL_WIN/TERMINAL_FOCUS"
let TERMINAL_GEOMETRY = "TERMINAL_WIN/TERMINAL_GEOMETRY"
let TERMINAL_REVISIONS = "TERMINAL_WIN/TERMINAL_REVISIONS"
let TERMINAL_SCREEN = "TERMINAL_WIN/TERMINAL_SCREEN"

[test]
def test_embedded_terminal_focus_and_input(t : T?) {
    let extra_modules <- ["modules/dasTerminal"]
    with_imgui_app(TERMINAL_FEATURE, extra_modules, "", "") $(d) {
        var initial = wait_for_render(d, TERMINAL_TARGET, 15.0f)
        t |> success(initial != null, "terminal surface renders")
        if (initial == null) return

        let entry = find_widget(initial, TERMINAL_TARGET)
        t |> equal(entry?["kind"] ?? "", "terminal", "snapshot kind is terminal")
        var geometry = wait_for_render(d, TERMINAL_GEOMETRY, 5.0f)
        t |> success(geometry != null, "terminal geometry telemetry renders")
        if (geometry != null) {
            let value = widget_payload_field(geometry, TERMINAL_GEOMETRY, "value") ?? ""
            t |> success(contains(value, "x") && !ends_with(value, ":0"),
                "first layout reports a measured and resized PTY grid")
        }

        click(d, TERMINAL_TARGET)
        t |> success(wait_for_mouse_idle(d), "terminal focus click timeline drains")
        t |> success(wait_for_string_value(d, TERMINAL_FOCUS, "value", "true", 300),
            "terminal focus effect becomes observable")

        let command = "Write-Output ('DASHERD_' + 'RESULT')\n"
        let typed = post_command(d, "imgui_key_type", JV((text = command)))
        t |> success(typed != null, "terminal accepts synthesized text")
        t |> success(wait_for_key_idle(d, 6.0f), "terminal key timeline drains")

        var output = wait_until_sec(d, 10.0f) $(var snap) {
            let screen = widget_payload_field(snap, TERMINAL_SCREEN, "value") ?? ""
            return contains(screen, "DASHERD_RESULT")
        }
        t |> success(output != null,
            "PowerShell result reaches the semantic terminal snapshot")
        if (output != null) {
            let revisions = widget_payload_field(output, TERMINAL_REVISIONS, "value") ?? "0:0"
            t |> success(revisions != "0:0", "input and content revisions advanced")
        }
    }
}
