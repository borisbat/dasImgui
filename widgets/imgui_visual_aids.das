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

// ===== State =====

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

var private g_trail_enabled : bool = false
var private g_trail_fade : float = 0.96f
var private g_trail_color : uint = 0xFFFFFFFFu
let private TRAIL_MAX_DOTS = 64

def private rgba(r, g, b, a : int) : uint {
    //! Pack a color into dasIMGUI's IM_COL32 byte order (0xAARRGGBB).
    //! Equivalent to the IM_COL32(R, G, B, A) macro in v1 daslib/imgui_boost,
    //! kept private so v2 doesn't depend on the v1 path.
    return ((uint(a) << uint(IM_COL32_A_SHIFT))
          | (uint(r) << uint(IM_COL32_R_SHIFT))
          | (uint(g) << uint(IM_COL32_G_SHIFT))
          | (uint(b) << uint(IM_COL32_B_SHIFT)))
}

let DEFAULT_HIGHLIGHT_COLOR : uint = (255u << 24u) | (255u << 16u) | (255u << 8u) | 0u  // 0xFFFFFF00 — yellow
let DEFAULT_HIGHLIGHT_FRAMES = 60
let DEFAULT_NARRATE_FRAMES = 180

var public imgui_auto_highlight_on_command : bool = false
    //! When true, every accepted command in imgui_boost_runtime
    //! (imgui_click / imgui_set / imgui_focus / etc.) auto-calls
    //! `highlight(target, 60)` after the action. Wiring lands in 4.5.

// ===== User API =====

def public highlight(target : string;
                     frames : int = DEFAULT_HIGHLIGHT_FRAMES;
                     color : uint = DEFAULT_HIGHLIGHT_COLOR) {
    //! Flash a colored rect around the named widget's bbox for `frames`
    //! end_of_frame ticks. `target` is a registry path (`"Setup/SAVE_BTN"`)
    //! or hex_id (`"0x4f3a2b1c"`). `color` is ABGR packed via IM_COL32.
    g_highlights |> push(HighlightSpec(target = target, remaining_frames = frames, color = color))
}

def public mouse_trail(enabled : bool;
                       fade : float = 0.96f;
                       color : uint = 0xFFFFFFFFu) {
    //! Toggle the fading mouse-trail overlay. Dots sample once per frame
    //! and decay over TRAIL_MAX_DOTS frames; `fade` is the per-frame alpha
    //! multiplier (≤1; closer to 1 keeps dots longer). `color` is ABGR.
    g_trail_enabled = enabled
    g_trail_fade = fade
    g_trail_color = color
    if (!enabled) {
        g_trail |> clear()
    }
}

def public narrate(text : string;
                   target : string = "";
                   frames : int = DEFAULT_NARRATE_FRAMES) {
    //! Pop a callout box with `text` on the foreground for N frames.
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
            *dl |> AddRect(
                float2(bb.x - 2.0f, bb.y - 2.0f),
                float2(bb.z + 2.0f, bb.w + 2.0f),
                g_highlights[i].color,
                2.0f,
                ImDrawFlags.None,
                2.0f
            )
        }
        g_highlights[i].remaining_frames--
        if (g_highlights[i].remaining_frames <= 0) {
            g_highlights |> erase(i)
        }
    }
}

def private paint_trail {
    if (!g_trail_enabled) return
    var dl = GetForegroundDrawList()
    let mouse = GetMousePos()
    g_trail |> push(TrailDot(pos = mouse, age_frames = 0))
    while (length(g_trail) > TRAIL_MAX_DOTS) {
        g_trail |> erase(0)
    }
    let base_rgb = g_trail_color & 0x00FFFFFFu
    var i = length(g_trail)
    while (i > 0) {
        i--
        let frac = 1.0f - float(g_trail[i].age_frames) / float(TRAIL_MAX_DOTS)
        if (frac <= 0.0f) {
            g_trail |> erase(i)
            continue
        }
        let alpha_f = clamp(frac * 255.0f * g_trail_fade, 0.0f, 255.0f)
        let color = base_rgb | (uint(alpha_f) << 24u)
        *dl |> AddCircleFilled(g_trail[i].pos, 4.0f * frac + 1.0f, color, 12)
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
        // FontGlobalScale and any active font, so the box fits the rendered text
        // including 1.5× scale that examples typically set.
        let text_size = CalcTextSize(g_narrates[i].text, false, -1.0f)
        let pad_x = 8.0f
        let pad_y = 4.0f
        let box_end = float2(anchor.x + text_size.x + pad_x * 2.0f,
                             anchor.y + text_size.y + pad_y * 2.0f)
        let bg = rgba(32, 32, 32, 204)
        let fg = rgba(255, 255, 255, 255)
        let border = rgba(255, 204, 51, 255)
        *dl |> AddRectFilled(anchor, box_end, bg, 4.0f, ImDrawFlags.None)
        *dl |> AddRect(anchor, box_end, border, 4.0f, ImDrawFlags.None, 1.5f)
        *dl |> AddText(float2(anchor.x + pad_x, anchor.y + pad_y), fg, g_narrates[i].text)
        if (have_target) {
            let connector_start = float2(anchor.x, (anchor.y + box_end.y) * 0.5f)
            *dl |> AddLine(connector_start, widget_center, border, 1.5f)
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

[init]
def visual_aids_init {
    register_end_of_frame_hook("imgui_visual_aids", @@ paint_all)
}

// ===== Live commands =====

struct HighlightArgs {
    target : string
    @optional frames : int = DEFAULT_HIGHLIGHT_FRAMES
    @optional color : uint = DEFAULT_HIGHLIGHT_COLOR
}

[live_command(description="Flash a colored rect around the named widget's bbox for N frames.")]
def imgui_highlight(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<HighlightArgs>)
    highlight(args.target, args.frames, args.color)
    return JV((ok = true, target = args.target, frames = args.frames))
}

struct MouseTrailArgs {
    @optional enabled : bool = true
    @optional fade : float = 0.96f
    @optional color : uint = 0xFFFFFFFFu
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
    @optional frames : int = DEFAULT_NARRATE_FRAMES
}

[live_command(description="Show a callout box with text for N frames; optional target widget for connector line.")]
def imgui_narrate(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<NarrateArgs>)
    narrate(args.text, args.target, args.frames)
    return JV((ok = true))
}
