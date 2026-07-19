options gen2
options indenting = 4

module imgui_terminal shared

require imgui public
require terminal/terminal public
require clipboard/clipboard
require imgui/imgui_boost_runtime
require math
require strings

//! First interactive terminal view. Terminal cells remain the layout authority;
//! glyphs are clipped to the one- or two-cell rectangle assigned by the emulator.

struct public ImGuiTerminalStyle {
    background : float4 = float4(0.035f, 0.043f, 0.055f, 1.0f)
    foreground : float4 = float4(0.83f, 0.85f, 0.88f, 1.0f)
    cursor : float4 = float4(0.82f, 0.84f, 0.90f, 0.72f)
    focus_border : float4 = float4(0.30f, 0.56f, 0.92f, 1.0f)
    selection : float4 = float4(0.20f, 0.42f, 0.72f, 0.72f)
    cell_width : float = 0.0f
    line_height : float = 0.0f
    view_height : float = 0.0f
}

struct public ImGuiTerminalState {
    focused : bool
    columns : int
    rows : int
    render_revision : int
    resize_revision : int
    input_revision : int
    content_revision : int
    screen_text : string
    scroll_offset : int
    scrollback_rows : int
    cursor_visible : bool
    cursor_blinking : bool
    cursor_phase_visible : bool
    selection_active : bool
    selection_dragging : bool
    selection_anchor_row : int
    selection_anchor_column : int
    selection_focus_row : int
    selection_focus_column : int
    selection_revision : int
    paint_cells : int
    paint_special_cells : int
    paint_glyph_cells : int
    paint_text_runs : int
    paint_batched_cells : int
    perf_cache_refreshed : bool
    perf_snapshot_us : int
    perf_run_build_us : int
    perf_chrome_us : int
    perf_text_us : int
    perf_terminal_us : int
}

//! Cell projection cache kept separate from ImGuiTerminalState so live
//! inspection remains concise. Rebuilds only when terminal content, geometry,
//! active buffer, or scroll position changes.
struct public ImGuiTerminalCache {
    terminal_revision : int64 = -1l
    scroll_offset : int = -1
    snapshot : TerminalViewportSnapshot = TerminalViewportSnapshot()
    refreshed : bool
    snapshot_us : int
    run_build_us : int
}

struct public ImGuiTerminalResult {
    focused : bool
    resized : bool
    input_sent : bool
    paste_sent : bool
    selection_copied : bool
    selection_text : string
    columns : int
    rows : int
}

def private byte_char(value : int) : string {
    return to_char(value & 255)
}

def private codepoint_utf8(codepoint : int) : string {
    if (codepoint <= 0x7f) return byte_char(codepoint)
    if (codepoint <= 0x7ff) {
        return (byte_char(0xc0 | (codepoint >> 6)) +
            byte_char(0x80 | (codepoint & 0x3f)))
    }
    if (codepoint <= 0xffff) {
        return (byte_char(0xe0 | (codepoint >> 12)) +
            byte_char(0x80 | ((codepoint >> 6) & 0x3f)) +
            byte_char(0x80 | (codepoint & 0x3f)))
    }
    return (byte_char(0xf0 | (codepoint >> 18)) +
        byte_char(0x80 | ((codepoint >> 12) & 0x3f)) +
        byte_char(0x80 | ((codepoint >> 6) & 0x3f)) +
        byte_char(0x80 | (codepoint & 0x3f)))
}

def private indexed_color(index : int) : float4 {
    if (index == 0) return float4(0.00f, 0.00f, 0.00f, 1.0f)
    if (index == 1) return float4(0.80f, 0.16f, 0.16f, 1.0f)
    if (index == 2) return float4(0.20f, 0.72f, 0.30f, 1.0f)
    if (index == 3) return float4(0.80f, 0.66f, 0.20f, 1.0f)
    if (index == 4) return float4(0.25f, 0.43f, 0.82f, 1.0f)
    if (index == 5) return float4(0.72f, 0.30f, 0.76f, 1.0f)
    if (index == 6) return float4(0.20f, 0.70f, 0.72f, 1.0f)
    if (index == 7) return float4(0.72f, 0.74f, 0.76f, 1.0f)
    if (index < 16) {
        let bright = indexed_color(index - 8)
        return float4(min(1.0f, bright.x + 0.22f), min(1.0f, bright.y + 0.22f),
            min(1.0f, bright.z + 0.22f), 1.0f)
    }
    if (index < 232) {
        let cube = index - 16
        let r = cube / 36
        let g = (cube / 6) % 6
        let b = cube % 6
        return float4(float(r == 0 ? 0 : 55 + r * 40) / 255.0f,
            float(g == 0 ? 0 : 55 + g * 40) / 255.0f,
            float(b == 0 ? 0 : 55 + b * 40) / 255.0f, 1.0f)
    }
    let gray = float(8 + (index - 232) * 10) / 255.0f
    return float4(gray, gray, gray, 1.0f)
}

def private resolve_color(color : TerminalColor const; fallback : float4) : float4 {
    if (color.kind == TerminalColorKind.indexed) return indexed_color(color.index)
    if (color.kind == TerminalColorKind.rgb) {
        return float4(float(color.red) / 255.0f, float(color.green) / 255.0f,
            float(color.blue) / 255.0f, 1.0f)
    }
    return fallback
}

def private draw_terminal_cell_chrome(var dl : ImDrawList?; cell : TerminalCell const;
                                      display_row, rows : int;
                                      origin : float2; cell_width, line_height : float;
                                      style : ImGuiTerminalStyle const) {
    if (cell.width == 0 || display_row < 0 || display_row >= rows) return
    let inverse = (cell.attributes & 32) != 0
    let underline = (cell.attributes & 8) != 0
    let strike = (cell.attributes & 128) != 0
    if (!inverse && !underline && !strike
            && cell.background.kind == TerminalColorKind.default_color) return
    let p0 = origin + float2(float(cell.column) * cell_width,
        float(display_row) * line_height)
    let p1 = p0 + float2(cell_width * float(max(1, cell.width)), line_height)
    var fg = resolve_color(cell.foreground, style.foreground)
    var bg = resolve_color(cell.background, style.background)
    if (inverse) {
        let swap = fg
        fg = bg
        bg = swap
    }
    if (bg != style.background) {
        *dl |> AddRectFilled(p0, p1, GetColorU32(bg), 0.0f, ImDrawFlags.None)
    }
    if (underline) {
        *dl |> AddLine(float2(p0.x, p1.y - 1.0f), float2(p1.x, p1.y - 1.0f),
            GetColorU32(fg), 1.0f)
    }
    if (strike) {
        let y = p0.y + line_height * 0.55f
        *dl |> AddLine(float2(p0.x, y), float2(p1.x, y), GetColorU32(fg), 1.0f)
    }
}

def private draw_terminal_selection(var dl : ImDrawList?;
                                    state : ImGuiTerminalState const;
                                    columns, rows, visible_start_row : int;
                                    origin : float2; cell_width, line_height : float;
                                    style : ImGuiTerminalStyle const) {
    if (!state.selection_active) return
    let anchor = state.selection_anchor_row * columns + state.selection_anchor_column
    let focus = state.selection_focus_row * columns + state.selection_focus_column
    let first = min(anchor, focus)
    let last = max(anchor, focus) + 1
    for (display_row in range(0, rows)) {
        let row_first = (visible_start_row + display_row) * columns
        let overlap_first = max(first, row_first)
        let overlap_last = min(last, row_first + columns)
        if (overlap_last <= overlap_first) continue
        let first_column = overlap_first - row_first
        let last_column = overlap_last - row_first
        let p0 = origin + float2(float(first_column) * cell_width,
            float(display_row) * line_height)
        let p1 = origin + float2(float(last_column) * cell_width,
            float(display_row + 1) * line_height)
        *dl |> AddRectFilled(p0, p1, GetColorU32(style.selection), 0.0f, ImDrawFlags.None)
    }
}

def private batchable_ascii(cell : TerminalCell const) : bool {
    // Text runs carry color only. Styled and linked ASCII stays on the sparse
    // cell path so its attributes and OSC 8 metadata are not discarded.
    if (cell.width != 1 || cell.attributes != 0 || cell.hyperlink != ""
            || length(cell.grapheme) != 1) {
        return false
    }
    let value = cell.grapheme |> character_at(0) // nolint:PERF003 one byte per cached cell
    return value >= 32 && value <= 126
}

def private draw_terminal_text_runs(var dl : ImDrawList?;
                                    runs : array<TerminalTextRun> const;
                                    visible_start_row : int; origin : float2;
                                    cell_width, line_height : float;
                                    style : ImGuiTerminalStyle const;
                                    var state : ImGuiTerminalState) {
    for (run in runs) {
        let display_row = run.global_row - visible_start_row
        if (display_row < 0 || display_row >= state.rows) continue
        let fallback = run.default_is_background ? style.background : style.foreground
        let color = resolve_color(run.color, fallback)
        let p0 = origin + float2(float(run.column) * cell_width,
            float(display_row) * line_height)
        *dl |> AddText(p0, GetColorU32(color), run.text)
        state.paint_text_runs++
        state.paint_glyph_cells += run.glyph_cells
        state.paint_batched_cells += run.glyph_cells
    }
}

def private draw_terminal_fallback_cells(var dl : ImDrawList?;
                                         cells : array<TerminalCell> const; row_base : int;
                                         visible_start_row : int; origin : float2;
                                         cell_width, line_height : float;
                                         style : ImGuiTerminalStyle const;
                                         var state : ImGuiTerminalState) {
    for (cell in cells) {
        if (batchable_ascii(cell) || cell.width == 0 || cell.grapheme == ""
                || cell.grapheme == " "
                || (cell.attributes & TERMINAL_ATTR_HIDDEN) != 0) continue
        let global_row = row_base + cell.row
        let display_row = global_row - visible_start_row
        if (display_row < 0 || display_row >= state.rows) continue
        let inverse = (cell.attributes & 32) != 0
        let color = (inverse
            ? resolve_color(cell.background, style.background)
            : resolve_color(cell.foreground, style.foreground))
        let p0 = origin + float2(float(cell.column) * cell_width,
            float(display_row) * line_height)
        *dl |> AddText(p0, GetColorU32(color), cell.grapheme)
        state.paint_text_runs++
        state.paint_glyph_cells++
    }
}

def private selected_cell(cells : array<TerminalCell> const;
                          row, column, columns : int) : tuple<string; int> {
    //! Full terminal snapshots are canonical dense row-major projections.
    //! Preserve a defensive coordinate check so malformed external snapshots
    //! still produce a blank cell instead of returning the wrong grapheme.
    let index = row * columns + column
    if (index < 0 || index >= length(cells)) return (" ", 1)
    let cell = cells[index]
    if (cell.row != row || cell.column != column || cell.width <= 0) return (" ", 1)
    return (cell.grapheme, max(1, cell.width))
}

def private selected_text(buffer : TerminalBufferSnapshot const;
                          state : ImGuiTerminalState const; columns : int) : string {
    if (!state.selection_active) return ""
    let anchor = state.selection_anchor_row * columns + state.selection_anchor_column
    let focus = state.selection_focus_row * columns + state.selection_focus_column
    let first = min(anchor, focus)
    let last = max(anchor, focus)
    let first_row = first / columns
    let last_row = last / columns
    return build_string() $(var result) {
        for (row in range(first_row, last_row + 1)) {
            let first_column = row == first_row ? first % columns : 0
            let last_column = row == last_row ? last % columns : columns - 1
            var continuation_until = -1
            let line = build_string() $(var line_writer) {
                for (column in range(first_column, last_column + 1)) {
                    if (column < continuation_until) continue
                    if (row < buffer.scrollback_rows) {
                        let (grapheme, width) = selected_cell(
                            buffer.scrollback, row, column, columns)
                        line_writer |> write(grapheme)
                        continuation_until = column + width
                    } else {
                        let (grapheme, width) = selected_cell(
                            buffer.cells, row - buffer.scrollback_rows, column, columns)
                        line_writer |> write(grapheme)
                        continuation_until = column + width
                    }
                }
            }
            result |> write(line |> rtrim(" "))
            if (row != last_row) {
                result |> write("\n")
            }
        }
    }
}

def public imgui_terminal_clear_selection(var state : ImGuiTerminalState) {
    if (!state.selection_active && !state.selection_dragging) return
    state.selection_active = false
    state.selection_dragging = false
    state.selection_revision++
}

def public imgui_terminal_select_all(terminal : Terminal const;
                                     var state : ImGuiTerminalState) {
    var snapshot = TerminalSnapshot()
    terminal_snapshot(terminal, snapshot)
    let buffer <- snapshot.alternate_active ? snapshot.alternate : snapshot.normal
    let last_row = max(0, buffer.scrollback_rows + snapshot.rows - 1)
    state.selection_anchor_row = 0
    state.selection_anchor_column = 0
    state.selection_focus_row = last_row
    state.selection_focus_column = max(0, snapshot.columns - 1)
    state.selection_active = true
    state.selection_dragging = false
    state.selection_revision++
}

def public imgui_terminal_copy_selection(terminal : Terminal const;
                                         state : ImGuiTerminalState const) : bool {
    if (!state.selection_active) return false
    var snapshot = TerminalSnapshot()
    terminal_snapshot(terminal, snapshot)
    let buffer <- snapshot.alternate_active ? snapshot.alternate : snapshot.normal
    return clipboard_set_text(selected_text(buffer, state, snapshot.columns)) == ClipboardStatus.ok
}

def public imgui_terminal_paste_clipboard(terminal : Terminal const) : bool {
    var text = ""
    if (clipboard_get_text(text) != ClipboardStatus.ok) return false
    return terminal_send_paste(terminal, text)
}

def private pressed(key : ImGuiKey) : bool {
    return IsKeyPressed(key, false)
}

def private send_special(terminal : Terminal const; key : ImGuiKey;
                         terminal_key : TerminalKey; io : ImGuiIO const) : bool {
    if (!pressed(key)) return false
    return terminal_send_key(terminal, TerminalKeyEvent(
        key = terminal_key, shift = io.KeyShift, alt = io.KeyAlt,
        control = io.KeyCtrl))
}

def private route_input(terminal : Terminal const;
                        var state : ImGuiTerminalState) : tuple<bool; bool> {
    if (!state.focused) return (false, false)
    let io & = unsafe(GetIO())
    var sent = false
    var pasted = false
    sent = send_special(terminal, ImGuiKey.Enter, TerminalKey.enter, io) || sent
    sent = send_special(terminal, ImGuiKey.KeypadEnter, TerminalKey.enter, io) || sent
    sent = send_special(terminal, ImGuiKey.Tab, TerminalKey.tab, io) || sent
    sent = send_special(terminal, ImGuiKey.Backspace, TerminalKey.backspace, io) || sent
    sent = send_special(terminal, ImGuiKey.Escape, TerminalKey.escape, io) || sent
    sent = send_special(terminal, ImGuiKey.UpArrow, TerminalKey.up, io) || sent
    sent = send_special(terminal, ImGuiKey.DownArrow, TerminalKey.down, io) || sent
    sent = send_special(terminal, ImGuiKey.RightArrow, TerminalKey.right, io) || sent
    sent = send_special(terminal, ImGuiKey.LeftArrow, TerminalKey.left, io) || sent
    sent = send_special(terminal, ImGuiKey.Home, TerminalKey.home, io) || sent
    sent = send_special(terminal, ImGuiKey.End, TerminalKey.end, io) || sent
    sent = send_special(terminal, ImGuiKey.Insert, TerminalKey.insert, io) || sent
    sent = send_special(terminal, ImGuiKey.Delete, TerminalKey.delete_key, io) || sent
    sent = send_special(terminal, ImGuiKey.PageUp, TerminalKey.page_up, io) || sent
    sent = send_special(terminal, ImGuiKey.PageDown, TerminalKey.page_down, io) || sent
    sent = send_special(terminal, ImGuiKey.F1, TerminalKey.f1, io) || sent
    sent = send_special(terminal, ImGuiKey.F2, TerminalKey.f2, io) || sent
    sent = send_special(terminal, ImGuiKey.F3, TerminalKey.f3, io) || sent
    sent = send_special(terminal, ImGuiKey.F4, TerminalKey.f4, io) || sent
    sent = send_special(terminal, ImGuiKey.F5, TerminalKey.f5, io) || sent
    sent = send_special(terminal, ImGuiKey.F6, TerminalKey.f6, io) || sent
    sent = send_special(terminal, ImGuiKey.F7, TerminalKey.f7, io) || sent
    sent = send_special(terminal, ImGuiKey.F8, TerminalKey.f8, io) || sent
    sent = send_special(terminal, ImGuiKey.F9, TerminalKey.f9, io) || sent
    sent = send_special(terminal, ImGuiKey.F10, TerminalKey.f10, io) || sent
    sent = send_special(terminal, ImGuiKey.F11, TerminalKey.f11, io) || sent
    sent = send_special(terminal, ImGuiKey.F12, TerminalKey.f12, io) || sent

    if (io.KeyCtrl) {
        if (pressed(ImGuiKey.V)) {
            var text = ""
            if (clipboard_get_text(text) == ClipboardStatus.ok) {
                pasted = terminal_send_paste(terminal, text)
                sent = pasted || sent
            }
        } else {
            for (letter in range(0, 26)) {
                if (letter == 2 && state.selection_active) continue
                let imgui_key = unsafe(reinterpret<ImGuiKey>(int(ImGuiKey.A) + letter))
                if (pressed(imgui_key)) {
                    sent = terminal_send_key(terminal, TerminalKeyEvent(
                        key = TerminalKey.text, text = to_char(65 + letter),
                        shift = io.KeyShift, alt = io.KeyAlt, control = true)) || sent
                }
            }
        }
    } else {
        for (value in io.InputQueueCharacters) {
            let codepoint = int(value)
            if (codepoint > 0 && codepoint <= 0x10ffff) {
                sent = terminal_send_key(terminal, TerminalKeyEvent(
                    key = TerminalKey.text, text = codepoint_utf8(codepoint),
                    shift = io.KeyShift, alt = io.KeyAlt,
                    control = io.KeyCtrl)) || sent
            }
        }
    }
    if (sent) state.input_revision++
    return (sent, pasted)
}

def private refresh_terminal_cache(terminal : Terminal const; scroll_offset : int;
                                   var cache : ImGuiTerminalCache) : bool {
    let revision = terminal_revision(terminal)
    if (cache.terminal_revision == revision && cache.scroll_offset == scroll_offset) {
        return false
    }
    terminal_viewport_snapshot(terminal, scroll_offset, cache.snapshot)
    cache.snapshot_us += cache.snapshot.cell_projection_us
    cache.run_build_us += cache.snapshot.text_run_projection_us
    cache.refreshed = true
    cache.terminal_revision = cache.snapshot.revision
    cache.scroll_offset = clamp(scroll_offset, 0, cache.snapshot.buffer.scrollback_rows)
    return true
}

def public imgui_terminal(id : string; var terminal : Terminal;
                          var state : ImGuiTerminalState;
                          var cache : ImGuiTerminalCache;
                          style : ImGuiTerminalStyle = ImGuiTerminalStyle()) : ImGuiTerminalResult {
    let terminal_started = ref_time_ticks()
    cache.refreshed = false
    cache.snapshot_us = 0
    cache.run_build_us = 0
    var result = ImGuiTerminalResult()
    var snapshot_changed = refresh_terminal_cache(terminal, state.scroll_offset, cache)
    var snapshot & = unsafe(cache.snapshot)
    var cell_width = style.cell_width
    if (cell_width <= 0.0f) {
        cell_width = max(1.0f, CalcTextSize("M", false, -1.0f).x)
    }
    var line_height = style.line_height
    if (line_height <= 0.0f) {
        line_height = max(1.0f, GetTextLineHeight())
    }
    var available = GetContentRegionAvail()
    if (style.view_height > 0.0f) {
        available.y = min(available.y, style.view_height)
    }
    let columns = max(1, int(floor(available.x / cell_width)))
    let rows = max(1, int(floor(available.y / line_height)))
    if (columns != snapshot.columns || rows != snapshot.rows) {
        terminal_resize(terminal, columns, rows)
        if (refresh_terminal_cache(terminal, state.scroll_offset, cache)) {
            snapshot_changed = true
        }
        state.resize_revision++
        result.resized = true
    }
    state.columns = snapshot.columns
    state.rows = snapshot.rows
    result.columns = snapshot.columns
    result.rows = snapshot.rows

    let origin = GetCursorScreenPos()
    let extent = float2(cell_width * float(snapshot.columns),
        line_height * float(snapshot.rows))
    PushID(id)
    InvisibleButton("##terminal", extent)
    let hovered = IsItemHovered(ImGuiHoveredFlags.None)
    unsafe {
        register_clickable_state_bbox(id, "##terminal", "terminal", addr(state),
            reinterpret<TypeInfo const?>(typeinfo rtti_typeinfo(type<ImGuiTerminalState>)))
    }
    if (IsItemFocused()) {
        state.focused = true
    }
    if (hovered && IsMouseClicked(ImGuiMouseButton.Left, false)) {
        state.focused = true
    }
    if (!hovered && IsMouseClicked(ImGuiMouseButton.Left, false)) {
        state.focused = false
    }
    PopID()

    var dl = GetWindowDrawList()
    *dl |> AddRectFilled(origin, origin + extent, GetColorU32(style.background),
        0.0f, ImDrawFlags.None)
    *dl |> PushClipRect(origin, origin + extent, true)
    var buffer & = unsafe(snapshot.buffer)
    state.scrollback_rows = buffer.scrollback_rows
    if (snapshot_changed) {
        let current_screen_text = snapshot.screen_text
        if (current_screen_text != state.screen_text) {
            state.screen_text = current_screen_text
            state.content_revision++
        }
    }
    let io & = unsafe(GetIO())
    // Ctrl+wheel is reserved for application-level terminal zoom, matching
    // the Markdown viewer. Plain wheel continues to own scrollback.
    if (hovered && !io.KeyCtrl && io.MouseWheel != 0.0f) {
        let old_scroll_offset = state.scroll_offset
        state.scroll_offset = clamp(state.scroll_offset + int(io.MouseWheel * 3.0f),
            0, buffer.scrollback_rows)
        if (state.scroll_offset != old_scroll_offset) {
            let _ = refresh_terminal_cache(terminal, state.scroll_offset, cache)
        }
    } else {
        state.scroll_offset = clamp(state.scroll_offset, 0, buffer.scrollback_rows)
    }
    let visible_start_row = buffer.scrollback_rows - state.scroll_offset
    let local_mouse = io.MousePos - origin
    if (hovered && IsMouseClicked(ImGuiMouseButton.Left, false)) {
        let selected_row = visible_start_row + clamp(
            int(floor(local_mouse.y / line_height)), 0, snapshot.rows - 1)
        let selected_column = clamp(
            int(floor(local_mouse.x / cell_width)), 0, snapshot.columns - 1)
        state.selection_active = false
        state.selection_dragging = true
        state.selection_anchor_row = selected_row
        state.selection_anchor_column = selected_column
        state.selection_focus_row = selected_row
        state.selection_focus_column = selected_column
        state.selection_revision++
    } elif (hovered && state.selection_dragging && IsMouseDown(ImGuiMouseButton.Left)) {
        let selected_row = visible_start_row + clamp(
            int(floor(local_mouse.y / line_height)), 0, snapshot.rows - 1)
        let selected_column = clamp(
            int(floor(local_mouse.x / cell_width)), 0, snapshot.columns - 1)
        if (selected_row != state.selection_focus_row
                || selected_column != state.selection_focus_column) {
            state.selection_active = true
            state.selection_focus_row = selected_row
            state.selection_focus_column = selected_column
            state.selection_revision++
        }
    }
    if (state.selection_dragging && IsMouseReleased(ImGuiMouseButton.Left)) {
        state.selection_dragging = false
    }
    state.paint_cells = snapshot.columns * snapshot.rows
    state.paint_special_cells = 0
    state.paint_glyph_cells = 0
    state.paint_text_runs = 0
    state.paint_batched_cells = 0
    let chrome_started = ref_time_ticks()
    for (cell in buffer.scrollback) {
        let display_row = cell.row - visible_start_row
        if (cell.width > 0 && display_row >= 0 && display_row < state.rows) {
            state.paint_special_cells++
        }
        draw_terminal_cell_chrome(dl, cell, display_row, state.rows,
            origin, cell_width, line_height, style)
    }
    for (cell in buffer.cells) {
        let global_row = buffer.scrollback_rows + cell.row
        let display_row = global_row - visible_start_row
        if (cell.width > 0 && display_row >= 0 && display_row < state.rows) {
            state.paint_special_cells++
        }
        draw_terminal_cell_chrome(dl, cell, display_row, state.rows,
            origin, cell_width, line_height, style)
    }
    draw_terminal_selection(dl, state, snapshot.columns, snapshot.rows,
        visible_start_row, origin, cell_width, line_height, style)
    state.perf_chrome_us = get_time_usec(chrome_started)
    let text_started = ref_time_ticks()
    draw_terminal_text_runs(dl, snapshot.text_runs, visible_start_row,
        origin, cell_width, line_height, style, state)
    draw_terminal_fallback_cells(dl, buffer.scrollback, 0, visible_start_row,
        origin, cell_width, line_height, style, state)
    draw_terminal_fallback_cells(dl, buffer.cells, buffer.scrollback_rows, visible_start_row,
        origin, cell_width, line_height, style, state)
    state.perf_text_us = get_time_usec(text_started)
    state.cursor_visible = buffer.cursor.visible
    state.cursor_blinking = buffer.cursor.blinking
    state.cursor_phase_visible = (buffer.cursor.visible
        && (!buffer.cursor.blinking || !state.focused
            || fmod(float(GetTime()), 1.0f) < 0.5f))
    if (state.cursor_phase_visible && state.scroll_offset == 0) {
        let cp0 = origin + float2(float(buffer.cursor.column) * cell_width,
            float(buffer.cursor.row) * line_height)
        *dl |> AddRectFilled(cp0, cp0 + float2(max(1.0f, cell_width * 0.12f), line_height),
            GetColorU32(style.cursor), 0.0f, ImDrawFlags.None)
    }
    *dl |> PopClipRect()
    if (state.focused) {
        *dl |> AddRect(origin, origin + extent, GetColorU32(style.focus_border),
            0.0f, ImDrawFlags.None, 1.0f)
    }
    if (state.focused && state.selection_active && io.KeyCtrl && pressed(ImGuiKey.C)) {
        var copy_snapshot = TerminalSnapshot()
        terminal_snapshot(terminal, copy_snapshot)
        let copy_buffer <- copy_snapshot.alternate_active ? copy_snapshot.alternate : copy_snapshot.normal
        let copy_text = selected_text(copy_buffer, state, copy_snapshot.columns)
        result.selection_text = copy_text
        result.selection_copied = clipboard_set_text(copy_text) == ClipboardStatus.ok
    }
    let (sent, pasted) = route_input(terminal, state)
    result.input_sent = sent
    result.paste_sent = pasted
    result.focused = state.focused
    state.perf_cache_refreshed = cache.refreshed
    state.perf_snapshot_us = cache.snapshot_us
    state.perf_run_build_us = cache.run_build_us
    state.perf_terminal_us = get_time_usec(terminal_started)
    state.render_revision++
    return <- result
}

//! Compatibility overload for callers which do not retain a cache. Interactive
//! terminal hosts should pass a persistent ImGuiTerminalCache.
def public imgui_terminal(id : string; var terminal : Terminal;
                          var state : ImGuiTerminalState;
                          style : ImGuiTerminalStyle = ImGuiTerminalStyle()) : ImGuiTerminalResult {
    var cache = ImGuiTerminalCache()
    return <- imgui_terminal(id, terminal, state, cache, style)
}
