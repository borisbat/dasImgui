options gen2
// TODO: this tutorial uses pre-v2 raw imgui calls (Text/Spacing/Separator/
// SameLine etc.) and needs a follow-up rewrite to use the v2 wrappers
// (text/spacing/separator/same_line). Opt out of the default-on lint until
// that pass lands so the file stays compileable.
options _allow_imgui_legacy = true

require imgui
require imgui_app
require glfw/glfw_boost
require opengl/opengl_boost
require live/glfw_live
require live/live_api
require live/live_commands
require live/live_vars
require live/opengl_live
require live_host
require imgui/imgui_live
require imgui/imgui_boost_runtime
require imgui/imgui_boost_v2
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_visual_aids
require imgui/imgui_colors

require math
require strings

// =============================================================================
// TUTORIAL: custom_widgets — write your own widget kind with [widget].
//
// ImGui core ships no rotary control; here we add one. The knob:
//   - is a single [widget] def at module scope, ~30 lines including drawlist
//   - plugs into pending_value_finalize + one [widget_dispatch] — same
//     state-struct convention as slider_float, so imgui_snapshot reflects it
//     and imgui_force_set drives it, exactly like a built-in
//   - uses the canonical InvisibleButton + DrawList pattern for the body
//
// Read alongside :ref:`tutorial_widgets_tour` for the built-in catalog.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/custom_widgets.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/custom_widgets.das
//
// DRIVE (when running live):
//   curl -X POST -d '{"name":"imgui_force_set","args":{"target":"MIXER_WIN/MASTER","value":0.75}}'   localhost:9090/command
//   curl -X POST -d '{"name":"imgui_force_set","args":{"target":"MIXER_WIN/TREBLE","value":-0.3}}'   localhost:9090/command
//   curl -X POST -d '{"name":"imgui_click","args":{"target":"MIXER_WIN/RESET_BTN"}}'           localhost:9090/command
// =============================================================================

//! State struct for the knob — same five-field convention as ``SliderStateFloat``
//! so :ref:`pending_value_finalize <function-imgui_boost_runtime_pending_value_finalize>`
//! can drive it without modification.
struct VolumeKnobState {
    @live value : float                   //! current knob value, preserved across reload
    @live bounds : tuple<float; float>    //! (min, max) — set per-frame at the call site
    @optional has_pending : bool          //! imgui_force_set queued; consumed next frame
    @optional pending_value : float       //! next-frame value queued by imgui_force_set
    @optional changed : bool              //! true on the frame the widget fired
}

// imgui_force_set's "set" action queues pending_value (drained in knob() step 1).
// The dispatch half of the custom-widget rail; pending_value_finalize is the other.
[widget_dispatch]
def knob_dispatch(var state : VolumeKnobState; action : string; payload : string) {
    if (action == "set") {
        state.pending_value = to_float(payload)
        state.has_pending = true
    }
}

//! Rotary knob — vertical-drag value control with a 270° indicator arc.
//! ``widget_ident`` is injected at position 1 by the ``[widget]`` annotation;
//! pass it to ``pending_value_finalize`` at the bottom.
[widget]
def knob(var state : VolumeKnobState; text : string) : bool {
    // 1. Drain imgui_force_set: any pending dispatcher-side update lands here.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds

    // 2. Reserve a hitbox. InvisibleButton is the "registered" item that
    //    widget_finalize (via the [widget] postlude) attaches bbox/hex_id/
    //    hover/active/focus to. Hitbox = knob disc + label + value readout,
    //    so the whole rendered widget is one ImGui-layout cell of fixed
    //    width — adjacent knobs stay aligned regardless of value-text width.
    let p = GetCursorScreenPos()
    let sz = ImVec2(72.0f, 112.0f)             // 72×72 knob + 24 label + 16 value
    let radius = 30.0f
    let center = ImVec2(p.x + sz.x * 0.5f, p.y + 36.0f)
    InvisibleButton(text, sz)

    // 3. Drag handling — mouse position relative to center drives the
    //    angle directly. atan2 returns (-π, π]; shifting by -3π/4 and
    //    wrapping into [0, 2π) puts the active arc into [0, 3π/2) and the
    //    bottom-gap dead zone into [3π/2, 2π). Dead-zone clicks are
    //    ignored — value holds at its previous reading.
    var changed = false
    if (IsItemActive()) {
        let mp = GetIO().MousePos
        var th = atan2(mp.y - center.y, mp.x - center.x) - 3.0f * PI / 4.0f
        if (th < 0.0f) {
            th += 2.0f * PI
        }
        if (th < 3.0f * PI / 2.0f) {
            let f = th / (3.0f * PI / 2.0f)
            let new_val = clamp(mn + f * (mx - mn), mn, mx)
            if (new_val != state.value) {
                state.value = new_val
                changed = true
            }
        }
    }
    state.changed = changed

    // 4. Draw via the window's drawlist. Indicator sweeps a 270° arc with
    //    a 90° gap at the bottom (DAW convention):
    //       frac = 0 → θ = 3π/4   (bottom-left, "7 o'clock")
    //       frac = 0.5 → θ = 3π/2 (straight up, "12 o'clock")
    //       frac = 1 → θ = 9π/4   (bottom-right, "5 o'clock")
    //    ImGui's y-axis points down, so positive sin is down; the formula
    //    is monotonic in θ and the inverse of step 3's mapping.
    let frac = (state.value - mn) / (mx - mn)
    let theta = 3.0f * PI / 4.0f + frac * 3.0f * PI / 2.0f
    let tip = ImVec2(
        center.x + cos(theta) * radius * 0.82f,
        center.y + sin(theta) * radius * 0.82f
    )
    let hovered = IsItemHovered()
    let rim_col = hovered ? rgba(190u, 200u, 220u, 255u) : rgba(120u, 130u, 150u, 255u)
    *GetWindowDrawList() |> AddCircleFilled(center, radius, rgba(40u, 42u, 48u, 255u), 32)
    *GetWindowDrawList() |> AddCircle(center, radius, rim_col, 32, 2.0f)
    *GetWindowDrawList() |> AddLine(center, tip, rgba(220u, 200u, 60u, 255u), 3.0f)

    // 5. Label + value readout, both drawlist (no ImGui layout impact).
    let label_size = CalcTextSize(text, false, -1.0f)
    let label_pos = ImVec2(center.x - label_size.x * 0.5f, p.y + 76.0f)
    *GetWindowDrawList() |> AddText(label_pos, rgba(220u, 220u, 220u, 255u), text)
    let val_str = build_string() <| $(var w) {
        fmt(w, ":.2f", state.value)
    }
    let val_size = CalcTextSize(val_str, false, -1.0f)
    let val_pos = ImVec2(center.x - val_size.x * 0.5f, p.y + 94.0f)
    *GetWindowDrawList() |> AddText(val_pos, rgba(170u, 170u, 180u, 255u), val_str)

    // 6. Register state + serializer (snapshot, and force_set draining). Same call
    //    any slider makes; the [widget_dispatch] above routes the live "set" in.
    pending_value_finalize(widget_ident, "knob", state)
    return changed
}

[export]
def init() {
    live_create_window("dasImgui custom_widgets", 800, 520)
    live_imgui_init(live_window)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    apply_synth_io_override()
    NewFrame()

    SetNextWindowPos(ImVec2(60.0f, 60.0f), ImGuiCond.Always)
    SetNextWindowSize(ImVec2(680.0f, 380.0f), ImGuiCond.Always)
    window(MIXER_WIN, (text = "Mastering", closable = false,
                       flags = ImGuiWindowFlags.None)) {
        Text("Three knobs from one [widget] def - different state globals.")
        Spacing()

        // Each knob is one ImGui-layout cell (fixed 72×112 hitbox), so
        // SameLine spacing is constant regardless of value-text width.
        MASTER.bounds = (0.0f, 1.0f)
        knob(MASTER, (text = "Master"))
        SameLine()
        TREBLE.bounds = (-1.0f, 1.0f)
        knob(TREBLE, (text = "Treble"))
        SameLine()
        BASS.bounds = (-1.0f, 1.0f)
        knob(BASS, (text = "Bass"))

        Spacing()
        Separator()
        Spacing()

        // Ordinary built-in widget on the same panel — imgui_click works on it.
        if (button(RESET_BTN, (text = "Reset"))) {
            MASTER.value = 0.5f
            TREBLE.value = 0.0f
            BASS.value = 0.0f
        }
    }

    end_of_frame()
    Render()
    var w, h : int
    live_get_framebuffer_size(w, h)
    glViewport(0, 0, w, h)
    glClearColor(0.10f, 0.10f, 0.12f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)
    ImGui_ImplOpenGL3_RenderDrawData(GetDrawData())

    live_end_frame()
}

[export]
def shutdown() {
    live_imgui_shutdown()
    live_destroy_window()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
