options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

module imgui_visual_aids shared public

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_live
require live/live_commands
require live_host
require daslib/json public
require daslib/json_boost public
require strings
require math

// Module overview lives in handmade/module-imgui_visual_aids.rst.

def public rgba(r, g, b, a : int) : uint {
    //! Pack R/G/B/A bytes into ImGui's IM_COL32 word order. Useful when configuring the tunable color globals by channel rather than hex literal.
    // Hardcoded shifts to match the runtime ImGui build (standard RGBA mode:
    // R=0, G=8, B=16, A=24). The `IM_COL32_*_SHIFT` constants exposed via the
    // C++ bind are stuck at BGRA values (R=16, B=0) — that bind disagrees
    // with the actual runtime and renders R/B swapped. Source-level fix
    // keeps every existing dasImgui color literal visually honest.
    return (uint(r)
          | (uint(g) << 8u)
          | (uint(b) << 16u)
          | (uint(a) << 24u))
}

// ===== Tunable knobs (var public) =====
//
// All visual settings live here as module globals. Reassign any of these
// from your app's init (or at runtime) to reskin the overlays. Per-call
// args on `highlight()` / `mouse_trail()` / `narrate()` still take
// precedence on a per-call basis.

// Manual highlight() — appearance when user code (or imgui_highlight curl)
// asks for a flash explicitly.
var public highlight_color          : uint  = rgba(255, 255, 0, 255)   // yellow
var public highlight_thickness      : float = 2.0f
var public highlight_padding        : float = 2.0f
var public highlight_rounding       : float = 2.0f
var public highlight_default_frames : int   = 60

// Auto-flash on remote command — when imgui_auto_highlight_on_command is
// true. Visually distinct from manual highlights so viewers can tell
// which actions were driven remotely vs. user-issued.
var public auto_highlight_color  : uint = rgba(0, 255, 128, 255)        // bright green
var public auto_highlight_frames : int  = 180                            // ~2s at 90fps

// Mouse trail
var public trail_max_dots   : int   = 64
var public trail_color      : uint  = rgba(255, 255, 255, 255)
var public trail_dot_radius : float = 4.0f
var public trail_fade       : float = 0.96f
var public trail_enabled    : bool  = false

// Cursor sprite — drawn at io.MousePos inside ImGui's foreground drawlist, so
// it shows up in glReadPixels-based recordings (the OS hardware cursor never
// hits the GL back buffer). Off by default; enable during APNG recording.
var public cursor_sprite_enabled            : bool  = false
var public cursor_sprite_color              : uint  = rgba(255, 64, 64, 255)
var public cursor_sprite_outline_color      : uint  = rgba(255, 255, 255, 255)
var public cursor_sprite_radius             : float = 9.0f
var public cursor_sprite_outline_thickness  : float = 2.0f
var public cursor_sprite_inner_radius       : float = 2.5f

// Click flash — expanding ring drawn at the cursor when imgui_live's synth
// driver fires a button press. The overlay is the recording's proof-of-click
// — useful when the widget's own hover/active visuals don't fire for a
// synthetic click (e.g. because the backend's per-frame poll fights over
// io.MousePos with our synth state).
var public click_flash_enabled       : bool  = true
var public click_flash_color         : uint  = rgba(255, 255, 0, 255)   // yellow
var public click_flash_start_radius  : float = 8.0f
var public click_flash_end_radius    : float = 36.0f
var public click_flash_thickness     : float = 2.5f
var public click_flash_duration_s    : float = 0.35f

// Narrate callout — post-it-note look: vivid yellow body, dark text, soft shadow.
var public narrate_bg_color       : uint  = rgba(255, 236, 130, 240)    // post-it yellow #FFEC82
var public narrate_fg_color       : uint  = rgba(30, 25, 10, 255)       // near-black warm #1E190A
var public narrate_border_color   : uint  = rgba(200, 160, 30, 255)     // darker amber #C8A01E
var public narrate_border_thickness : float = 1.5f
var public narrate_pad_x          : float = 12.0f
var public narrate_pad_y          : float = 8.0f
var public narrate_corner_radius  : float = 2.0f
var public narrate_default_frames : int   = 180
var public narrate_connector_thickness : float = 1.5f
var public narrate_shadow_color   : uint  = rgba(0, 0, 0, 90)
var public narrate_shadow_offset  : float2 = float2(3.0f, 4.0f)

// Auto-highlight gate
var public imgui_auto_highlight_on_command : bool = false
    //! When true, every accepted imgui_* command auto-flashes its target with ``auto_highlight_color`` for ``auto_highlight_frames`` ticks.

// Keycap / modifier HUD — bottom-center keycap pops + modifier-strip below.
// Reads `synth_last_codepoint` / `synth_last_keycode` from imgui_live to
// detect each new synth key event and pop a new keycap. Modifier strip
// lights up directly from `IsKeyDown(ImGuiKey_*)` so it reacts to BOTH
// synth events AND real hardware keys.
var public key_hud_enabled              : bool   = false
var public key_hud_show_modifiers       : bool   = true
var public key_hud_offset_y_from_bottom : float  = 80.0f
var public key_hud_keycap_color         : uint   = rgba(40, 40, 40, 230)
var public key_hud_keycap_border_color  : uint   = rgba(255, 255, 255, 200)
var public key_hud_text_color           : uint   = rgba(255, 255, 255, 255)
var public key_hud_keycap_w             : float  = 44.0f
var public key_hud_keycap_h             : float  = 36.0f
var public key_hud_keycap_spacing       : float  = 6.0f
var public key_hud_keycap_rounding      : float  = 6.0f
var public key_hud_keycap_border_thick  : float  = 1.5f
var public key_hud_keycap_fade_s        : float  = 0.7f
var public key_hud_mod_strip_y_gap      : float  = 8.0f
var public key_hud_mod_pill_w           : float  = 56.0f
var public key_hud_mod_pill_h           : float  = 20.0f
var public key_hud_mod_pill_spacing     : float  = 6.0f
var public key_hud_mod_pill_rounding    : float  = 10.0f
var public key_hud_mod_active_color     : uint   = rgba(255, 200, 80, 255)
var public key_hud_mod_idle_color       : uint   = rgba(80, 80, 80, 180)
var public key_hud_mod_active_text      : uint   = rgba(20, 20, 20, 255)
var public key_hud_mod_idle_text        : uint   = rgba(220, 220, 220, 255)
let g_keycap_trace_max = 6                                  // most-recent N keycaps still on screen
let g_keycap_trace_fallback_lifetime_s = 1.0f               // safety cap on a stuck trace

// Focus rectangle — halo around io.active_widget. Off by default; opt in via
// imgui_focus_rect for tutorial recordings. Useful when typing into a text
// input — without this halo there's nothing on screen tying the keycap HUD's
// output to the destination widget.
var public focus_rect_enabled   : bool  = false
var public focus_rect_color     : uint  = rgba(80, 180, 255, 220)            // cyan
var public focus_rect_thickness : float = 2.0f
var public focus_rect_padding   : float = 3.0f
var public focus_rect_rounding  : float = 3.0f

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

struct private KeycapTrace {
    glyph    : string         // rendered keycap text ("A", "Enter", "Tab", ...)
    t_pushed : float          // get_uptime() when added; used for fade-out
}

var private g_keycap_traces  : array<KeycapTrace>
var private g_last_seen_codepoint_t : float = -1.0    // mirror of synth_last_codepoint_t; only push a new trace when this advances
var private g_last_seen_keycode_t   : float = -1.0    // mirror of synth_last_keycode_t; pushed only when no char event represents it

// ===== User API =====

def public highlight(target : string;
                     frames : int = highlight_default_frames;
                     color : uint = highlight_color) {
    //! Flash a colored rect around the named widget's bbox for ``frames`` ticks. ``target`` is a registry path or ``"0x<hex_id>"``.
    g_highlights |> push(HighlightSpec(target = target, remaining_frames = frames, color = color))
}

def public mouse_trail(enabled : bool;
                       fade : float = -1.0f;
                       color : uint = 0u) {
    //! Toggle the fading mouse-trail overlay; non-default ``fade`` / ``color`` override the module globals. Disabling clears the trail buffer.
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

def public cursor_sprite(enabled : bool) {
    //! Toggle the in-frame cursor sprite. Drawn on the ForegroundDrawList so APNG recordings show a visible pointer even when the OS hardware cursor isn't captured.
    cursor_sprite_enabled = enabled
}

def public apply_synth_io_override() {
    //! Per-frame synth IO entry point — call between the backend's ``NewFrame`` and ImGui's ``NewFrame``. Drives :ref:`imgui_synth_tick <function-imgui_live_core_imgui_synth_tick>`.
    imgui_synth_tick()
}

def public narrate(text : string;
                   target : string = "";
                   frames : int = narrate_default_frames) {
    //! Pop a callout box with ``text`` for ``frames`` ticks. If ``target`` resolves to a widget bbox the box anchors next to it with a connector line; otherwise it floats top-left.
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

def private effective_cursor_pos() : float2 {
    // Synth cursor when active, else real ImGui cursor — backend poll may overwrite io.MousePos.
    let (active, sx, sy) = imgui_live::get_synth_cursor()
    return float2(sx, sy) if (active)
    return GetMousePos()
}

def private paint_trail {
    if (!trail_enabled) return
    var dl = GetForegroundDrawList()
    let mouse = effective_cursor_pos()
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

def private fits_viewport(c : float2; box_size : float2; viewport : float2;
                          edge_margin : float; shadow : float2; hud_zone_h : float) : bool {
    let max_x = viewport.x - edge_margin - box_size.x - shadow.x
    let max_y = viewport.y - edge_margin - box_size.y - shadow.y - hud_zone_h
    return (c.x >= edge_margin && c.x <= max_x
         && c.y >= edge_margin && c.y <= max_y)
}

def private overlaps_any(c : float2; box_size : float2; bboxes : array<float4>) : bool {
    // Box-on-box overlap test: candidate (c, c+box_size) vs each bbox (x0,y0,x1,y1).
    // Touching edges count as non-overlapping (>= / <=, not > / <).
    let bx1 = c.x + box_size.x
    let by1 = c.y + box_size.y
    for (b in bboxes) {
        if (!(bx1 <= b.x || c.x >= b.z || by1 <= b.y || c.y >= b.w)) {
            return true
        }
    }
    return false
}

def public compute_narrate_anchor(
                                  has_target   : bool;
                                  widget_bbox  : float4;
                                  box_size     : float2;
                                  viewport     : float2;
                                  edge_margin  : float;
                                  gap          : float;
                                  shadow       : float2;
                                  hud_zone_h   : float;
                                  other_bboxes : array<float4>
                                  ) : float2 {
    //! Pick a post-it anchor (top-left corner) that fits the viewport without
    //! overlapping the target widget OR any other registered widget. Tries
    //! right → left → below → above of the target; falls back to a
    //! viewport-clamped right placement if nothing fits cleanly (e.g. text
    //! wider than the viewport, or every neighbor blocks).
    if (!has_target) {
        return float2(edge_margin, edge_margin)
    }
    let bb = widget_bbox
    let cx = (bb.x + bb.z) * 0.5f

    // 1. Right of widget
    var c = float2(bb.z + gap, bb.y)
    if (fits_viewport(c, box_size, viewport, edge_margin, shadow, hud_zone_h)
        && !overlaps_any(c, box_size, other_bboxes)) {
        return c
    }
    // 2. Left of widget
    c = float2(bb.x - gap - box_size.x, bb.y)
    if (fits_viewport(c, box_size, viewport, edge_margin, shadow, hud_zone_h)
        && !overlaps_any(c, box_size, other_bboxes)) {
        return c
    }
    // 3. Below widget (horizontally centered)
    c = float2(cx - box_size.x * 0.5f, bb.w + gap)
    if (fits_viewport(c, box_size, viewport, edge_margin, shadow, hud_zone_h)
        && !overlaps_any(c, box_size, other_bboxes)) {
        return c
    }
    // 4. Above widget (horizontally centered)
    c = float2(cx - box_size.x * 0.5f, bb.y - gap - box_size.y)
    if (fits_viewport(c, box_size, viewport, edge_margin, shadow, hud_zone_h)
        && !overlaps_any(c, box_size, other_bboxes)) {
        return c
    }
    // Fallback: keep right placement and clamp into viewport. Only fires when
    // no candidate fits — typically text wider than viewport, or a widget
    // that covers most of the screen.
    var fb = float2(bb.z + gap, bb.y)
    let max_x = viewport.x - edge_margin - box_size.x - shadow.x
    let max_y = viewport.y - edge_margin - box_size.y - shadow.y - hud_zone_h
    if (fb.x > max_x) {
        fb.x = max_x
    }
    if (fb.x < edge_margin) {
        fb.x = edge_margin
    }
    if (fb.y > max_y) {
        fb.y = max_y
    }
    if (fb.y < edge_margin) {
        fb.y = edge_margin
    }
    return fb
}

def public compute_connector_start(
                                   anchor        : float2;
                                   box_size      : float2;
                                   widget_center : float2
                                   ) : float2 {
    //! Midpoint of the post-it edge closest to the widget center. Used to
    //! anchor the connector line from the right edge when the post-it sits
    //! to the left of the widget, etc.
    let cx = anchor.x + box_size.x * 0.5f
    let cy = anchor.y + box_size.y * 0.5f
    let dx = widget_center.x - cx
    let dy = widget_center.y - cy
    if (abs(dx) > abs(dy)) {
        return dx > 0.0f ? float2(anchor.x + box_size.x, cy) : float2(anchor.x, cy)
    }
    return dy > 0.0f ? float2(cx, anchor.y + box_size.y) : float2(cx, anchor.y)
}

def private narrate_hud_zone_h : float {
    //! Bottom screen reserve so narrates don't collide with the key_hud
    //! keycap row + modifier strip when the HUD is enabled.
    if (!key_hud_enabled) {
        return 0.0f
    }
    return key_hud_offset_y_from_bottom + key_hud_mod_pill_h + key_hud_mod_strip_y_gap
}

def private paint_narrates {
    if (empty(g_narrates)) return
    var dl = GetForegroundDrawList()
    var io & = unsafe(GetIO())
    let viewport = io.DisplaySize
    let edge_margin = 8.0f
    let gap = 16.0f
    let hud_zone_h = narrate_hud_zone_h()
    var i = length(g_narrates)
    while (i > 0) {
        i--
        // Actual text size via the CalcTextSize shim (main.cpp:342) — picks up
        // FontGlobalScale and any active font, so the box fits the rendered text.
        let text_size = CalcTextSize(g_narrates[i].text, false, -1.0f)
        let box_size = float2(text_size.x + narrate_pad_x * 2.0f,
                              text_size.y + narrate_pad_y * 2.0f)

        var have_target = false
        var widget_bbox = float4(0.0f, 0.0f, 0.0f, 0.0f)
        var widget_center = float2(0.0f, 0.0f)
        if (!empty(g_narrates[i].target)) {
            let r = widget_rect(g_narrates[i].target)
            if (r._0) {
                widget_bbox = r._1
                widget_center = float2((widget_bbox.x + widget_bbox.z) * 0.5f,
                                       (widget_bbox.y + widget_bbox.w) * 0.5f)
                have_target = true
            }
        }
        // Collect every registered widget bbox except the target's, so the
        // post-it doesn't land on a sibling. Cheap: linear scan of the
        // per-frame registry, typically ≤ 30 entries.
        var other_bboxes : array<float4>
        for (k, w in keys(imgui_boost_runtime::g_registry), values(imgui_boost_runtime::g_registry)) {
            if (have_target && k == g_narrates[i].target) {
                continue
            }
            other_bboxes |> push(w.bbox)
        }
        let anchor = compute_narrate_anchor(have_target, widget_bbox, box_size,
                                            viewport, edge_margin, gap,
                                            narrate_shadow_offset, hud_zone_h,
                                            other_bboxes)
        delete other_bboxes
        let box_end = float2(anchor.x + box_size.x, anchor.y + box_size.y)
        // Drop shadow first so the post-it sits on top of it.
        *dl |> AddRectFilled(anchor + narrate_shadow_offset, box_end + narrate_shadow_offset,
                             narrate_shadow_color, narrate_corner_radius, ImDrawFlags.None)
        *dl |> AddRectFilled(anchor, box_end, narrate_bg_color, narrate_corner_radius, ImDrawFlags.None)
        *dl |> AddRect(anchor, box_end, narrate_border_color, narrate_corner_radius, ImDrawFlags.None, narrate_border_thickness)
        *dl |> AddText(float2(anchor.x + narrate_pad_x, anchor.y + narrate_pad_y), narrate_fg_color, g_narrates[i].text)
        if (have_target) {
            let conn_start = compute_connector_start(anchor, box_size, widget_center)
            *dl |> AddLine(conn_start, widget_center, narrate_border_color, narrate_connector_thickness)
        }
        g_narrates[i].remaining_frames--
        if (g_narrates[i].remaining_frames <= 0) {
            g_narrates |> erase(i)
        }
    }
}

def private paint_cursor_sprite {
    if (!cursor_sprite_enabled) return
    var dl = GetForegroundDrawList()
    let p = effective_cursor_pos()
    *dl |> AddCircleFilled(p, cursor_sprite_radius, cursor_sprite_color, 16)
    *dl |> AddCircle(p, cursor_sprite_radius, cursor_sprite_outline_color, 16, cursor_sprite_outline_thickness)
    *dl |> AddCircleFilled(p, cursor_sprite_inner_radius, cursor_sprite_outline_color, 12)
}

def private effective_synth_click() : tuple<int; float> {
    // (action, t) for last synth click — action: 1=press, 0=release.
    return (imgui_live::synth_click_action, imgui_live::synth_click_t)
}

def private paint_click_flash {
    // Only fire on press, not release; skip if disabled or never clicked.
    let (action, t) = effective_synth_click()
    return if (!click_flash_enabled || t < 0.0 || action != 1)
    let elapsed = float(get_uptime()) - t
    return if (elapsed < 0.0 || elapsed > click_flash_duration_s)
    let alpha_f = (1.0f - elapsed / click_flash_duration_s) * 255.0f
    let radius = click_flash_start_radius + (click_flash_end_radius - click_flash_start_radius) * (elapsed / click_flash_duration_s)
    let color = (click_flash_color & 0x00FFFFFFu) | (uint(alpha_f) << 24u)
    var dl = GetForegroundDrawList()
    *dl |> AddCircle(effective_cursor_pos(), radius, color, 24, click_flash_thickness)
}

def private glyph_for_codepoint(cp : uint) : string {
    if (cp == uint('\n') || cp == uint('\r')) return "Enter"
    if (cp == uint('\t')) return "Tab"
    if (cp == uint(' ')) return "Space"
    if (cp == 8u) return "Bksp"
    if (cp == 27u) return "Esc"
    return "?" if (cp < 0x20u || cp >= 0x7Fu)
    return build_string() $(writer) {
        writer |> write_char(int(cp))
    }
}

def private glyph_for_imgui_key(kc : int) : string {
    if (kc == int(ImGuiKey.Enter)) return "Enter"
    if (kc == int(ImGuiKey.Tab)) return "Tab"
    if (kc == int(ImGuiKey.Backspace)) return "Bksp"
    if (kc == int(ImGuiKey.Escape)) return "Esc"
    if (kc == int(ImGuiKey.Space)) return "Space"
    if (kc == int(ImGuiKey.LeftArrow)) return "<-"
    if (kc == int(ImGuiKey.RightArrow)) return "->"
    if (kc == int(ImGuiKey.UpArrow)) return "Up"
    if (kc == int(ImGuiKey.DownArrow)) return "Down"
    if (kc == int(ImGuiKey.LeftShift) || kc == int(ImGuiKey.RightShift)) return "Shift"
    if (kc == int(ImGuiKey.LeftCtrl)  || kc == int(ImGuiKey.RightCtrl)) return "Ctrl"
    if (kc == int(ImGuiKey.LeftAlt)   || kc == int(ImGuiKey.RightAlt)) return "Alt"
    if (kc == int(ImGuiKey.LeftSuper) || kc == int(ImGuiKey.RightSuper)) return "Cmd"
    return ""    // unknown — caller skips the trace
}

def private paint_key_hud {
    return if (!key_hud_enabled)

    // 1) Pull new synth events from imgui_live into traces. Codepoint takes
    //    priority: a typed char already includes the visible glyph;
    //    modifier-only keystrokes fall through to the keycode branch.
    let now = float(get_uptime())
    let cp_t = imgui_live::synth_last_codepoint_t
    let cp   = imgui_live::synth_last_codepoint
    let kc_t = imgui_live::synth_last_keycode_t
    let kc   = imgui_live::synth_last_keycode
    if (cp_t > g_last_seen_codepoint_t && cp != 0u) {
        g_keycap_traces |> push(KeycapTrace(glyph = glyph_for_codepoint(cp), t_pushed = now))
        g_last_seen_codepoint_t = cp_t
        // Mark this keycode as "represented by char"; if a key press at the
        // same instant fires next, don't double-push.
        g_last_seen_keycode_t = kc_t
    } elif (kc_t > g_last_seen_keycode_t && kc != 0) {
        let g = glyph_for_imgui_key(kc)
        if (!empty(g)) {
            g_keycap_traces |> push(KeycapTrace(glyph = g, t_pushed = now))
        }
        g_last_seen_keycode_t = kc_t
    }

    // 2) Drop traces older than fade duration.
    var i = length(g_keycap_traces)
    while (i > 0) {
        i--
        if (now - g_keycap_traces[i].t_pushed > key_hud_keycap_fade_s) {
            g_keycap_traces |> erase(i)
        }
    }
    // Cap to the most-recent N (keeps a runaway script from filling the row).
    while (length(g_keycap_traces) > g_keycap_trace_max) {
        g_keycap_traces |> erase(0)
    }

    // 3) Layout bottom-center. ImGui's main viewport gives the window size in
    //    pixels — use it for the anchor.
    let viewport = GetMainViewport()
    let vp_size = viewport.Size
    let vp_pos  = viewport.Pos
    let n = length(g_keycap_traces)
    var dl = GetForegroundDrawList()

    if (n > 0) {
        // Pre-measure each glyph and grow the per-cap width when the label
        // is wider than the default — keeps "Space" / "Enter" / "Shift"
        // from overflowing the keycap box.
        var cap_widths : array<float>
        cap_widths |> resize(n)
        var row_w = 0.0f
        for (j in range(n)) {
            let label_size = CalcTextSize(g_keycap_traces[j].glyph, false, -1.0f)
            let w = max(key_hud_keycap_w, label_size.x + key_hud_keycap_w * 0.4f)
            cap_widths[j] = w
            row_w += w
            if (j > 0) {
                row_w += key_hud_keycap_spacing
            }
        }
        let row_y = vp_pos.y + vp_size.y - key_hud_offset_y_from_bottom - key_hud_keycap_h
        var x = vp_pos.x + (vp_size.x - row_w) * 0.5f
        for (j in range(n)) {
            let trace = g_keycap_traces[j]
            let elapsed = now - trace.t_pushed
            let fade = clamp(1.0f - elapsed / key_hud_keycap_fade_s, 0.0f, 1.0f)
            let bg     = (key_hud_keycap_color        & 0x00FFFFFFu) | (uint(float(key_hud_keycap_color        >> 24u) * fade) << 24u)
            let border = (key_hud_keycap_border_color & 0x00FFFFFFu) | (uint(float(key_hud_keycap_border_color >> 24u) * fade) << 24u)
            let text   = (key_hud_text_color          & 0x00FFFFFFu) | (uint(float(key_hud_text_color          >> 24u) * fade) << 24u)
            let cap_w = cap_widths[j]
            let p0 = float2(x, row_y)
            let p1 = float2(x + cap_w, row_y + key_hud_keycap_h)
            *dl |> AddRectFilled(p0, p1, bg, key_hud_keycap_rounding, ImDrawFlags.None)
            *dl |> AddRect(p0, p1, border, key_hud_keycap_rounding, ImDrawFlags.None, key_hud_keycap_border_thick)
            let label_size = CalcTextSize(trace.glyph, false, -1.0f)
            let tx = x + (cap_w - label_size.x) * 0.5f
            let ty = row_y + (key_hud_keycap_h - label_size.y) * 0.5f
            *dl |> AddText(float2(tx, ty), text, trace.glyph)
            x += cap_w + key_hud_keycap_spacing
        }
    }

    // 4) Modifier strip — pulls direct from ImGui's live key state so it
    //    works for both synth events and real hardware keys.
    if (key_hud_show_modifiers) {
        let names = ["Ctrl", "Shift", "Alt", "Cmd"]
        let active = [
            IsKeyDown(ImGuiKey.LeftCtrl)  || IsKeyDown(ImGuiKey.RightCtrl),
            IsKeyDown(ImGuiKey.LeftShift) || IsKeyDown(ImGuiKey.RightShift),
            IsKeyDown(ImGuiKey.LeftAlt)   || IsKeyDown(ImGuiKey.RightAlt),
            IsKeyDown(ImGuiKey.LeftSuper) || IsKeyDown(ImGuiKey.RightSuper)
        ]
        let strip_n = 4
        let strip_w = float(strip_n) * key_hud_mod_pill_w + float(strip_n - 1) * key_hud_mod_pill_spacing
        let strip_y = vp_pos.y + vp_size.y - key_hud_offset_y_from_bottom + key_hud_mod_strip_y_gap
        var sx = vp_pos.x + (vp_size.x - strip_w) * 0.5f
        for (k in range(strip_n)) {
            let bg   = active[k] ? key_hud_mod_active_color : key_hud_mod_idle_color
            let text = active[k] ? key_hud_mod_active_text  : key_hud_mod_idle_text
            let p0 = float2(sx, strip_y)
            let p1 = float2(sx + key_hud_mod_pill_w, strip_y + key_hud_mod_pill_h)
            *dl |> AddRectFilled(p0, p1, bg, key_hud_mod_pill_rounding, ImDrawFlags.None)
            let label_size = CalcTextSize(names[k], false, -1.0f)
            let tx = sx + (key_hud_mod_pill_w - label_size.x) * 0.5f
            let ty = strip_y + (key_hud_mod_pill_h - label_size.y) * 0.5f
            *dl |> AddText(float2(tx, ty), text, names[k])
            sx += key_hud_mod_pill_w + key_hud_mod_pill_spacing
        }
    }
}

def private paint_focus_rect {
    return if (!focus_rect_enabled)
    let path = active_widget_path()
    return if (empty(path))
    let r = widget_rect(path)
    return if (!r._0)
    let bb = r._1
    let pad = focus_rect_padding
    var dl = GetForegroundDrawList()
    *dl |> AddRect(
        float2(bb.x - pad, bb.y - pad),
        float2(bb.z + pad, bb.w + pad),
        focus_rect_color,
        focus_rect_rounding,
        ImDrawFlags.None,
        focus_rect_thickness
    )
}

def private paint_all {
    paint_highlights()
    paint_trail()
    paint_narrates()
    paint_focus_rect()
    paint_cursor_sprite()
    paint_click_flash()
    paint_key_hud()
}

def private on_command(command : string; target : string) {
    if (imgui_auto_highlight_on_command && !empty(target)) {
        highlight(target, auto_highlight_frames, auto_highlight_color)
    }
}

[init]
def visual_aids_init {
    //! ``[init]`` — registers the foreground-drawlist paint hook and the post-command auto-highlight hook. Runs once at module load.
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
    //! ``[live_command]`` wrapper around :ref:`highlight <function-imgui_visual_aids_highlight_string_int_uint>`. Args: ``target``, ``frames``, ``color``.
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
    //! ``[live_command]`` wrapper around :ref:`mouse_trail <function-imgui_visual_aids_mouse_trail_bool_float_uint>`. Args: ``enabled``, ``fade``, ``color``.
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
    //! ``[live_command]`` wrapper around :ref:`narrate <function-imgui_visual_aids_narrate_string_string_int>`. Args: ``text``, ``target``, ``frames``.
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
    //! ``[live_command]`` toggle for the ``imgui_auto_highlight_on_command`` flag. Arg: ``enabled``.
    let args = from_JV(input, type<AutoHighlightArgs>)
    imgui_auto_highlight_on_command = args.enabled
    return JV((ok = true, enabled = args.enabled))
}

struct CursorSpriteArgs {
    @optional enabled : bool = true
}

[live_command(description="Toggle the in-frame cursor sprite. Enable before record_start so the recording shows a visible cursor pointer.")]
def imgui_cursor_sprite(input : JsonValue?) : JsonValue? {
    //! ``[live_command]`` wrapper around :ref:`cursor_sprite <function-imgui_visual_aids_cursor_sprite_bool>`. Arg: ``enabled``.
    let args = from_JV(input, type<CursorSpriteArgs>)
    cursor_sprite(args.enabled)
    return JV((ok = true, enabled = args.enabled))
}

struct KeyHudArgs {
    @optional enabled         : bool = true
    @optional show_modifiers  : bool = true
}

[live_command(description="Toggle the keycap + modifier-strip HUD. Pops a keycap at bottom-center for every synth key event and lights up Ctrl/Shift/Alt/Cmd pills while held.")]
def imgui_key_hud(input : JsonValue?) : JsonValue? {
    //! ``[live_command]`` toggle for the bottom-center keycap HUD + Ctrl/Shift/Alt/Cmd modifier strip. Args: ``enabled``, ``show_modifiers``.
    let args = from_JV(input, type<KeyHudArgs>)
    key_hud_enabled = args.enabled
    key_hud_show_modifiers = args.show_modifiers
    return JV((ok = true, enabled = args.enabled, show_modifiers = args.show_modifiers))
}

struct FocusRectArgs {
    @optional enabled : bool = true
}

[live_command(description="Toggle the focus rectangle around io.active_widget. Shows where typing lands; opt-in for tutorial recordings.")]
def imgui_focus_rect(input : JsonValue?) : JsonValue? {
    //! ``[live_command]`` toggle for the focus rectangle around ``io.active_widget`` — shows where typing lands. Arg: ``enabled``.
    let args = from_JV(input, type<FocusRectArgs>)
    focus_rect_enabled = args.enabled
    return JV((ok = true, enabled = args.enabled))
}
