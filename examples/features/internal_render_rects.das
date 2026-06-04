options gen2

require imgui/imgui_harness

// =============================================================================
// FEATURE: internal_render_rects — completes the imgui_internal.h Render* family
//          (#1) with the four helpers that take an ImRect and so were left out of
//          the original family-1 PR. Now that ImRect is aliased to float4 (#166),
//          they bind directly (bind_imgui.das internal_allow_func). An ImRect is a
//          float4 of (Min.x, Min.y, Max.x, Max.y). RenderNavHighlight also pulls
//          the ImGuiNavHighlightFlags_ enum (bound as an int arg, like PushItemFlag).
//          This is the "binding is usable" gate — it calls the real bound API at
//          runtime, not just compiles it.
// SHOWS:   RenderRectFilledRangeH (fill a horizontal sub-range of a rounded rect),
//          RenderRectFilledWithHole (fill an outer rect minus an inner rect),
//          RenderDragDropTargetRect (the highlight drawn over a drag-drop target),
//          RenderNavHighlight (the keyboard/gamepad nav focus ring).
// STANDALONE: daslang.exe modules/dasImgui/examples/features/internal_render_rects.das
// HEADLESS:   daslang.exe modules/dasImgui/examples/features/internal_render_rects.das -- --headless --headless-frames=60
// LIVE:       daslang-live modules/dasImgui/examples/features/internal_render_rects.das
// =============================================================================

[export]
def init() {
    harness_init("internal_render_rects - imgui_internal.h Render* ImRect helpers", 760, 560)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.25
}

[export]
def update() {
    if (!harness_begin_frame()) return
    harness_new_frame()

    let ink   = rgba(232u, 232u, 240u, 255u)
    let fill  = rgba(48u, 96u, 168u, 230u)
    let edge  = rgba(120u, 180u, 240u, 255u)
    let amber = rgba(232u, 168u, 64u, 230u)

    SetNextWindowSize(ImVec2(720.0, 520.0), ImGuiCond.Always)
    window(RECTS_WIN, (text = "internal_render_rects", closable = false,
                       flags = ImGuiWindowFlags.None)) {
        text("imgui_internal.h Render* helpers that take an ImRect (float4 Min/Max).")
        separator()

        // RenderRectFilledRangeH - fill a [x_start_norm, x_end_norm] sub-range of a
        // rounded rect (the primitive behind progress bars / scrollbar grabs).
        text("RenderRectFilledRangeH: fill a horizontal 0.12..0.68 sub-range of a rounded rect.")
        let o1 = GetCursorScreenPos()
        with_window_drawlist() $(var dl) {
            let tx = o1.x + 12.0
            let ty = o1.y + 10.0
            let track = float4(tx, ty, tx + 420.0, ty + 34.0)
            dl |> add_rect(ImVec2(tx, ty), ImVec2(tx + 420.0, ty + 34.0), edge, 6.0, ImDrawFlags.None, 2.0)
            RenderRectFilledRangeH(dl, track, fill, 0.12, 0.68, 6.0)
            dl |> add_text(ImVec2(tx + 8.0, ty + 9.0), ink, "0.12 .. 0.68")
        }
        dummy(SPACER1, ImVec2(700.0, 56.0))
        separator()

        // RenderRectFilledWithHole - fill the outer rect except the inner rect (a
        // frame / focus mask). Both corners are ImRects.
        text("RenderRectFilledWithHole: fill an outer rect minus an inner rect (a frame).")
        let o2 = GetCursorScreenPos()
        with_window_drawlist() $(var dl) {
            let ox = o2.x + 12.0
            let oy = o2.y + 8.0
            let outer = float4(ox, oy, ox + 300.0, oy + 70.0)
            let inner = float4(ox + 42.0, oy + 18.0, ox + 258.0, oy + 52.0)
            RenderRectFilledWithHole(dl, outer, inner, amber, 6.0)
            dl |> add_text(ImVec2(ox + 312.0, oy + 26.0), ink, "outer minus inner")
        }
        dummy(SPACER2, ImVec2(700.0, 88.0))
        separator()

        // RenderDragDropTargetRect - the highlight ImGui paints over an accepting
        // drag-drop target. Draws into the current window's drawlist (no dl arg);
        // the second ImRect clips the highlight.
        text("RenderDragDropTargetRect: the highlight drawn over a drag-drop target.")
        let o3 = GetCursorScreenPos()
        let dropBB = float4(o3.x + 12.0, o3.y + 8.0, o3.x + 320.0, o3.y + 60.0)
        let dropClip = float4(o3.x, o3.y, o3.x + 700.0, o3.y + 76.0)
        RenderDragDropTargetRect(dropBB, dropClip)
        dummy(SPACER3, ImVec2(700.0, 72.0))
        separator()

        // RenderNavHighlight - the keyboard/gamepad nav focus ring. It only paints the
        // item whose id equals the current nav id; at rest that id is 0, so passing 0
        // with AlwaysDraw shows the ring here. Tab/arrow nav moves it to the real item.
        text("RenderNavHighlight: the nav focus ring (id 0 + AlwaysDraw to show at rest).")
        let o4 = GetCursorScreenPos()
        let navBB = float4(o4.x + 12.0, o4.y + 8.0, o4.x + 320.0, o4.y + 50.0)
        RenderNavHighlight(navBB, 0u, int(ImGuiNavHighlightFlags.AlwaysDraw))
        dummy(SPACER4, ImVec2(700.0, 62.0))
        separator()
        text("All four are imgui_internal.h Render* helpers, unblocked by ImRect (family #1).")
    }

    harness_end_frame()
}

[export]
def shutdown() {
    harness_shutdown()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
