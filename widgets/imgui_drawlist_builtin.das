options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

module imgui_drawlist_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require math

//! Drawlist rail — scope wrappers + primitive functions for ImGui's three
//! drawlists (window / foreground / background). Same telemetry surface as
//! ``[widget]`` (kind + bbox land in ``g_registry`` under the leaf path key
//! ``<window>/<mod>:<line>:<col>``) but no per-call state global. Path keys
//! are mouse-cards / playwright targetable for click / hover assertions.
//!
//! Usage:
//!
//!   with_window_drawlist() $(var dl) {
//!       dl |> add_rect_filled(p0, p1, rgba(40u, 80u, 200u, 200u))
//!       dl |> add_line(a, b, rgba(255u, 255u, 0u, 255u), 2.0f)
//!   }
//!
//! Each ``add_*`` primitive is tagged ``[drawlist_prim]`` so the
//! ``DrawlistPrimCallMacro`` rewrites the call site, prepending a stable
//! ``<mod>:<line>:<col>`` path key as the first positional argument. The
//! primitive body forwards to the raw ``ImDrawList::Add*`` binding and then
//! calls ``drawlist_register`` to publish a lightweight ``WidgetEntry``
//! (kind + bbox, no hover/active/focus, no serializer/dispatcher).

// ===== Telemetry helper =====

def public drawlist_register(widget_ident : string; kind : string; bbox : float4) {
    //! Publish a drawlist primitive's per-frame snapshot. Path key is
    //! ``container_path/widget_ident``; ``widget_ident`` is the
    //! ``<mod>:<line>:<col>`` synthesized by ``[drawlist_prim]``.
    //! No unique-render guard — drawlist primitives are decorative;
    //! a loop calling the same site N times is fine (last write wins
    //! on bbox; mouse-cards targeting hits the last-painted rect).
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    entry.kind = kind
    entry.hex_id = 0u
    entry.bbox = bbox
    g_registry[path] <- entry
}

// ===== Scope wrappers =====

def public with_window_drawlist(blk : block<(var dl : ImDrawList?) : void>) {
    //! Run ``blk`` with the current window's drawlist. Drawing is clipped
    //! to the window's content region and stacks under any subsequent
    //! widgets rendered in this window.
    var dl = GetWindowDrawList()
    invoke(blk, dl)
}

def public with_foreground_drawlist(blk : block<(var dl : ImDrawList?) : void>) {
    //! Run ``blk`` with the top-most foreground drawlist — paints over
    //! every window on this viewport. Use for HUD overlays, drag indicators,
    //! tooltips that must escape window clipping.
    var dl = GetForegroundDrawList()
    invoke(blk, dl)
}

def public with_background_drawlist(blk : block<(var dl : ImDrawList?) : void>) {
    //! Run ``blk`` with the bottom-most background drawlist — paints under
    //! every window on this viewport. Use for full-viewport backdrops
    //! (gradients, vignettes, debug grids).
    var dl = GetBackgroundDrawList()
    invoke(blk, dl)
}

// ===== Primitives =====

[drawlist_prim]
def public add_line(var dl : ImDrawList?; a : float2; b : float2; col : uint;
                    thickness : float = 1.0f) {
    //! Stroked line from ``a`` to ``b``. ``col`` is a packed ABGR ``uint``
    //! (use ``rgba(r,g,b,a)`` or ``GetColorU32(ImGuiCol.*)`` to build).
    *dl |> AddLine(a, b, col, thickness)
    drawlist_register(widget_ident, "add_line",
                      float4(min(a.x, b.x), min(a.y, b.y), max(a.x, b.x), max(a.y, b.y)))
}

[drawlist_prim]
def public add_rect(var dl : ImDrawList?; a : float2; b : float2; col : uint;
                    rounding : float = 0.0f;
                    flags : ImDrawFlags = ImDrawFlags.None;
                    thickness : float = 1.0f) {
    //! Stroked rectangle. ``a`` / ``b`` are opposite corners (screen space).
    //! ``rounding`` rounds corners; ``flags`` (``ImDrawFlags.RoundCornersTop`` etc.)
    //! pick which corners are rounded.
    *dl |> AddRect(a, b, col, rounding, flags, thickness)
    drawlist_register(widget_ident, "add_rect", float4(a.x, a.y, b.x, b.y))
}

[drawlist_prim]
def public add_rect_filled(var dl : ImDrawList?; a : float2; b : float2; col : uint;
                           rounding : float = 0.0f;
                           flags : ImDrawFlags = ImDrawFlags.None) {
    //! Filled rectangle. Same coords / rounding / flags as ``add_rect``;
    //! no stroke thickness because the interior is solid.
    *dl |> AddRectFilled(a, b, col, rounding, flags)
    drawlist_register(widget_ident, "add_rect_filled", float4(a.x, a.y, b.x, b.y))
}

[drawlist_prim]
def public add_circle(var dl : ImDrawList?; center : float2; radius : float; col : uint;
                      num_segments : int = 0; thickness : float = 1.0f) {
    //! Stroked circle. ``num_segments=0`` (default) uses ImGui's adaptive
    //! ``CircleSegmentMaxError``-derived count — smooth at any radius.
    *dl |> AddCircle(center, radius, col, num_segments, thickness)
    drawlist_register(widget_ident, "add_circle",
                      float4(center.x - radius, center.y - radius,
                             center.x + radius, center.y + radius))
}

[drawlist_prim]
def public add_circle_filled(var dl : ImDrawList?; center : float2; radius : float; col : uint;
                             num_segments : int = 0) {
    //! Filled circle. ``num_segments=0`` uses ImGui's adaptive segment count.
    *dl |> AddCircleFilled(center, radius, col, num_segments)
    drawlist_register(widget_ident, "add_circle_filled",
                      float4(center.x - radius, center.y - radius,
                             center.x + radius, center.y + radius))
}

[drawlist_prim]
def public add_triangle(var dl : ImDrawList?; a : float2; b : float2; c : float2;
                        col : uint; thickness : float = 1.0f) {
    //! Stroked triangle through three vertices.
    *dl |> AddTriangle(a, b, c, col, thickness)
    let xs_min = min(min(a.x, b.x), c.x)
    let ys_min = min(min(a.y, b.y), c.y)
    let xs_max = max(max(a.x, b.x), c.x)
    let ys_max = max(max(a.y, b.y), c.y)
    drawlist_register(widget_ident, "add_triangle",
                      float4(xs_min, ys_min, xs_max, ys_max))
}

[drawlist_prim]
def public add_triangle_filled(var dl : ImDrawList?; a : float2; b : float2; c : float2;
                               col : uint) {
    //! Filled triangle through three vertices.
    *dl |> AddTriangleFilled(a, b, c, col)
    let xs_min = min(min(a.x, b.x), c.x)
    let ys_min = min(min(a.y, b.y), c.y)
    let xs_max = max(max(a.x, b.x), c.x)
    let ys_max = max(max(a.y, b.y), c.y)
    drawlist_register(widget_ident, "add_triangle_filled",
                      float4(xs_min, ys_min, xs_max, ys_max))
}

[drawlist_prim]
def public add_text(var dl : ImDrawList?; pos : float2; col : uint; text : string) {
    //! Render ``text`` at ``pos`` in the current ImGui font. ``col`` is the
    //! glyph color. Bbox is computed via ``CalcTextSize`` so playwright
    //! targeting on the text's path key resolves to its rendered rect.
    *dl |> AddText(pos, col, text)
    let sz = CalcTextSize(text)
    drawlist_register(widget_ident, "add_text",
                      float4(pos.x, pos.y, pos.x + sz.x, pos.y + sz.y))
}
