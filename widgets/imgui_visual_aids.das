options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_visual_aids shared public

require imgui public
require imgui/imgui_boost_runtime public
require live/live_commands
require daslib/json public
require daslib/json_boost public
require strings
require math

//! Visual-aids overlays for dasImgui.
//!
//! Three primitives, all painted on `ImGui::GetForegroundDrawList()` via an
//! `end_of_frame()` hook installed at module init:
//!
//!   - `highlight(target, frames, color)` — flash a colored rect around a
//!     widget's bbox for N frames.
//!   - `mouse_trail(enabled, fade, color)` — toggle a fading dot trail
//!     following the cursor.
//!   - `narrate(text, target, frames)` — callout box with optional
//!     connector line to a named widget.
//!
//! All three are also exposed as `[live_command] imgui_*` for remote drive
//! by daslang-live / playwright. `imgui_auto_highlight_on_command`
//! (default false) opts in to flashing every command target automatically.
//!
//! Tunables (colors, frame counts, padding, thickness, etc.) live as
//! `var public` module globals — set them at init time or whenever to
//! reskin the overlays. Per-call args still override on a per-flash basis.

def public rgba(r, g, b, a : int) : uint {
    //! Pack a color into dasIMGUI's IM_COL32 byte order. Used by callers
    //! that prefer named channels over hex literals when configuring the
    //! tunable globals below.
    return ((uint(a) << uint(IM_COL32_A_SHIFT))
          | (uint(r) << uint(IM_COL32_R_SHIFT))
          | (uint(g) << uint(IM_COL32_G_SHIFT))
          | (uint(b) << uint(IM_COL32_B_SHIFT)))
}

// ===== Tunable knobs (var public) =====
//
// All visual settings live here as module globals. Reassign any of these
// from your app's init (or at runtime) to reskin the overlays. Per-call
// args on `highlight()` / `mouse_trail()` / `narrate()` still take
// precedence on a per-call basis.

// Manual highlight() — appearance when user code (or imgui_highlight curl)
// asks for a flash explicitly.
var public highlight_color          : uint  = rgba(255, 255, 0, 255)   //! yellow
var public highlight_thickness      : float = 2.0f
var public highlight_padding        : float = 2.0f
var public highlight_rounding       : float = 2.0f
var public highlight_default_frames : int   = 60

// Auto-flash on remote command — when imgui_auto_highlight_on_command is
// true. Visually distinct from manual highlights so viewers can tell
// which actions were driven remotely vs. user-issued.
var public auto_highlight_color  : uint = rgba(0, 255, 128, 255)        //! bright green
var public auto_highlight_frames : int  = 180                            //! ~2s at 90fps

// Mouse trail
var public trail_max_dots   : int   = 64
var public trail_color      : uint  = rgba(255, 255, 255, 255)
var public trail_dot_radius : float = 4.0f
var public trail_fade       : float = 0.96f
var public trail_enabled    : bool  = false

// Narrate callout
var public narrate_bg_color       : uint  = rgba(32, 32, 32, 204)
var public narrate_fg_color       : uint  = rgba(255, 255, 255, 255)
var public narrate_border_color   : uint  = rgba(255, 204, 51, 255)     //! amber
var public narrate_border_thickness : float = 1.5f
var public narrate_pad_x          : float = 8.0f
var public narrate_pad_y          : float = 4.0f
var public narrate_corner_radius  : float = 4.0f
var public narrate_default_frames : int   = 180
var public narrate_connector_thickness : float = 1.5f

// Auto-highlight gate
var public imgui_auto_highlight_on_command : bool = false
    //! When true, every accepted command in imgui_boost_runtime
    //! (imgui_click / imgui_set / imgui_focus / etc.) auto-flashes the
    //! target with `auto_highlight_color` for `auto_highlight_frames` ticks.

// ===== Internal state =====

struct private HighlightSpec {
    target : string
    remaining_frames : int
    color : uint
}

struct private TrailDot {
    pos : float2
    age_frames : int
}

struct private NarrateSpec {
    text : string
    target : string
    remaining_frames : int
}

var private g_highlights : array<HighlightSpec>
var private g_trail : array<TrailDot>
var private g_narrates : array<NarrateSpec>

// ===== User API =====

def public highlight(target : string;
                     frames : int = highlight_default_frames;
                     color : uint = highlight_color) {
    //! Flash a colored rect around the named widget's bbox for `frames`
    //! end_of_frame ticks. `target` is a registry path (`"Setup/SAVE_BTN"`)
    //! or hex_id (`"0x4f3a2b1c"`). Defaults pull from the module globals
    //! `highlight_default_frames` / `highlight_color` — override per call
    //! when you want a one-off color.
    g_highlights |> push(HighlightSpec(target = target, remaining_frames = frames, color = color))
}

def public mouse_trail(enabled : bool;
                       fade : float = -1.0f;
                       color : uint = 0u) {
    //! Toggle the fading mouse-trail overlay. Defaults pull from `trail_fade`
    //! and `trail_color`; passing non-default values overrides the module
    //! globals for the new on-state. Disabling clears the trail buffer.
    trail_enabled = enabled
    if (fade >= 0.0f) {
        trail_fade = fade
    }
    if (color != 0u) {
        trail_color = color
    }
    if (!enabled) {
        g_trail |> clear()
    }
}

def public narrate(text : string;
                   target : string = "";
                   frames : int = narrate_default_frames) {
    //! Pop a callout box with `text` on the foreground for N frames.
    //! Colors / padding / corner-radius come from the `narrate_*` globals.
    //! When `target` resolves to a widget bbox the box anchors next to it
    //! with a connector line; otherwise it floats top-left.
    g_narrates |> push(NarrateSpec(text = text, target = target, remaining_frames = frames))
}

// ===== Painters =====

def private paint_highlights {
    if (empty(g_highlights)) return
    var dl = GetForegroundDrawList()
    var i = length(g_highlights)
    while (i > 0) {
        i--
        let r = widget_rect(g_highlights[i].target)
        if (r._0) {
            let bb = r._1
            let pad = highlight_padding
            *dl |> AddRect(
                float2(bb.x - pad, bb.y - pad),
                float2(bb.z + pad, bb.w + pad),
                g_highlights[i].color,
                highlight_rounding,
                ImDrawFlags.None,
                highlight_thickness
            )
        }
        g_highlights[i].remaining_frames--
        if (g_highlights[i].remaining_frames <= 0) {
            g_highlights |> erase(i)
        }
    }
}

def private paint_trail {
    if (!trail_enabled) return
    var dl = GetForegroundDrawList()
    let mouse = GetMousePos()
    g_trail |> push(TrailDot(pos = mouse, age_frames = 0))
    while (length(g_trail) > trail_max_dots) {
        g_trail |> erase(0)
    }
    let base_rgb = trail_color & 0x00FFFFFFu
    var i = length(g_trail)
    while (i > 0) {
        i--
        let frac = 1.0f - float(g_trail[i].age_frames) / float(trail_max_dots)
        if (frac <= 0.0f) {
            g_trail |> erase(i)
            continue
        }
        let alpha_f = clamp(frac * 255.0f * trail_fade, 0.0f, 255.0f)
        let color = base_rgb | (uint(alpha_f) << 24u)
        *dl |> AddCircleFilled(g_trail[i].pos, trail_dot_radius * frac + 1.0f, color, 12)
        g_trail[i].age_frames++
    }
}

def private paint_narrates {
    if (empty(g_narrates)) return
    var dl = GetForegroundDrawList()
    var i = length(g_narrates)
    while (i > 0) {
        i--
        var anchor = float2(40.0f, 40.0f)
        var have_target = false
        var widget_center = float2(0.0f, 0.0f)
        if (!empty(g_narrates[i].target)) {
            let r = widget_rect(g_narrates[i].target)
            if (r._0) {
                let bb = r._1
                anchor = float2(bb.z + 16.0f, bb.y)
                widget_center = float2((bb.x + bb.z) * 0.5f, (bb.y + bb.w) * 0.5f)
                have_target = true
            }
        }
        // Actual text size via the CalcTextSize shim (main.cpp:342) — picks up
        // FontGlobalScale and any active font, so the box fits the rendered text.
        let text_size = CalcTextSize(g_narrates[i].text, false, -1.0f)
        let box_end = float2(anchor.x + text_size.x + narrate_pad_x * 2.0f,
                             anchor.y + text_size.y + narrate_pad_y * 2.0f)
        *dl |> AddRectFilled(anchor, box_end, narrate_bg_color, narrate_corner_radius, ImDrawFlags.None)
        *dl |> AddRect(anchor, box_end, narrate_border_color, narrate_corner_radius, ImDrawFlags.None, narrate_border_thickness)
        *dl |> AddText(float2(anchor.x + narrate_pad_x, anchor.y + narrate_pad_y), narrate_fg_color, g_narrates[i].text)
        if (have_target) {
            let connector_start = float2(anchor.x, (anchor.y + box_end.y) * 0.5f)
            *dl |> AddLine(connector_start, widget_center, narrate_border_color, narrate_connector_thickness)
        }
        g_narrates[i].remaining_frames--
        if (g_narrates[i].remaining_frames <= 0) {
            g_narrates |> erase(i)
        }
    }
}

def private paint_all {
    paint_highlights()
    paint_trail()
    paint_narrates()
}

def private on_command(command : string; target : string) {
    //! Post-command hook: auto-flash the touched widget when
    //! `imgui_auto_highlight_on_command` is set. Uses the distinct
    //! `auto_highlight_color` / `auto_highlight_frames` knobs so viewers
    //! can tell command-driven flashes from manual `highlight()` ones.
    if (imgui_auto_highlight_on_command && !empty(target)) {
        highlight(target, auto_highlight_frames, auto_highlight_color)
    }
}

[init]
def visual_aids_init {
    register_end_of_frame_hook("imgui_visual_aids", @@ paint_all)
    register_post_command_hook("imgui_visual_aids", @@ on_command)
}

// ===== Live commands =====

struct HighlightArgs {
    target : string
    @optional frames : int = -1
    @optional color : uint = 0u
}

[live_command(description="Flash a colored rect around the named widget's bbox for N frames.")]
def imgui_highlight(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<HighlightArgs>)
    let frames = args.frames > 0 ? args.frames : highlight_default_frames
    let color = args.color != 0u ? args.color : highlight_color
    highlight(args.target, frames, color)
    return JV((ok = true, target = args.target, frames = frames))
}

struct MouseTrailArgs {
    @optional enabled : bool = true
    @optional fade : float = -1.0f
    @optional color : uint = 0u
}

[live_command(description="Toggle the fading mouse-trail overlay. Args: enabled, fade, color.")]
def imgui_mouse_trail(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<MouseTrailArgs>)
    mouse_trail(args.enabled, args.fade, args.color)
    return JV((ok = true, enabled = args.enabled))
}

struct NarrateArgs {
    text : string
    @optional target : string = ""
    @optional frames : int = -1
}

[live_command(description="Show a callout box with text for N frames; optional target widget for connector line.")]
def imgui_narrate(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<NarrateArgs>)
    let frames = args.frames > 0 ? args.frames : narrate_default_frames
    narrate(args.text, args.target, frames)
    return JV((ok = true))
}

struct AutoHighlightArgs {
    @optional enabled : bool = true
}

[live_command(description="Toggle the imgui_auto_highlight_on_command flag — when on, every accepted command auto-flashes its target.")]
def imgui_auto_highlight(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<AutoHighlightArgs>)
    imgui_auto_highlight_on_command = args.enabled
    return JV((ok = true, enabled = args.enabled))
}
