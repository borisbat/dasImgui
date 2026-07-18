options gen2
options indenting = 4
options no_unused_function_arguments = false

module imgui_text_source_view shared

require imgui public
require imgui/imgui_text_source_model public
require imgui/imgui_fonts public
require clipboard/clipboard
require math
require strings

//! Selectable read-only source presentation shared by text viewers and the
//! future editor. Layout is cell-based but source positions remain UTF-8 byte
//! offsets. Color emoji/CJK reserve two cells; combining and ZWJ sequences are
//! atomic graphemes. Glyph drawing is centered and clipped to its cell box.

bitfield public TextSourceSelectionStyles {
    all_regular
    has_markers
    has_mixed_styles
}

struct public TextSourceSelection {
    active : bool = false
    source : TextSourceRange = TextSourceRange(start_byte = -1, end_byte = -1)
    styles : TextSourceSelectionStyles
    screen_valid : bool = false
    screen_bounds : float4
    screen_anchor : float2
}

struct public TextSourceViewResult {
    selection : TextSourceSelection = TextSourceSelection()
    selection_changed : bool = false
    selection_copied : bool = false
    selection_copy_requested : bool = false
    selection_copy_text : string
    selection_context_requested : bool = false
    selection_context_pos : float2
}

struct public TextSourceViewStyle {
    fonts : FontRoleSet = FontRoleSet()
    zoom : float = 1.0f
    text_color : float4 = float4(0.86f, 0.87f, 0.89f, 1.0f)
    marker_color : float4 = float4(0.97f, 0.76f, 0.34f, 1.0f)
    selection_color : float4 = float4(0.24f, 0.48f, 0.78f, 0.55f)
    caret_color : float4 = float4(0.92f, 0.92f, 0.94f, 1.0f)
    wrap : bool = false
    tab_cells : int = 4
    write_system_clipboard : bool = true
}

struct public TextSourceCell {
    source : TextSourceRange
    style_id : int = 0
    line_index : int = -1
    rect : float4
    columns : int = 1
    natural_width : float = 0.0f
}

struct public TextSourceLayoutKey {
    document_revision : int = -1
    max_width : float = 0.0f
    font_size : float = 0.0f
    line_height : float = 0.0f
    cell_width : float = 0.0f
    font_id : uint64 = 0uL
    wrap : bool = false
    tab_cells : int = 4
}

struct public TextSourceViewState {
    key : TextSourceLayoutKey = TextSourceLayoutKey()
    layout_valid : bool = false
    layout : TextFlowLayout
    cells : array<TextSourceCell>
    screen_origin : float2
    screen_size : float2

    anchor_byte : int = -1
    focus_byte : int = -1
    selection_dragging : bool = false
    selection_changed : bool = false
    selection_screen_valid : bool = false
    selection_screen_bounds : float4
    selection_screen_anchor : float2
    caret_screen_valid : bool = false
    caret_screen_pos : float2
    caret_screen_height : float = 0.0f

    render_revision : int = 0
    selection_revision : int = 0
    selection_commit_revision : int = 0
    selection_copy_revision : int = 0
    selection_copy_pending : bool = false
    selection_copy_text : string
    selection_context_revision : int = 0
    selection_context_pos : float2
    navigation_revision : int = 0
    layout_hits : int = 0
    layout_misses : int = 0
}

let private SOURCE_STYLE_REGULAR = 0
let private SOURCE_STYLE_MARKER = 1

def private source_zoom(style : TextSourceViewStyle const) : float {
    return clamp(style.zoom, 0.5f, 3.0f)
}

def private source_font(var style : TextSourceViewStyle; var fallback : ImFont?) : ImFont? {
    return style.fonts.monospace != null ? style.fonts.monospace : fallback
}

def private same_layout_key(a, b : TextSourceLayoutKey const) : bool {
    return (a.document_revision == b.document_revision
        && a.max_width == b.max_width && a.font_size == b.font_size
        && a.line_height == b.line_height && a.cell_width == b.cell_width
        && a.font_id == b.font_id && a.wrap == b.wrap
        && a.tab_cells == b.tab_cells)
}

def private selected_source(state : TextSourceViewState const) : TextSourceRange {
    if (state.anchor_byte < 0 || state.focus_byte < 0) {
        return TextSourceRange(start_byte = -1, end_byte = -1)
    }
    return TextSourceRange(start_byte = min(state.anchor_byte, state.focus_byte),
                           end_byte = max(state.anchor_byte, state.focus_byte))
}

def public text_source_view_selection(state : TextSourceViewState const) : TextSourceRange {
    return selected_source(state)
}

def public text_source_view_clear_selection(var state : TextSourceViewState) {
    let had_selection = state.anchor_byte >= 0 || state.focus_byte >= 0
    state.anchor_byte = -1
    state.focus_byte = -1
    state.selection_dragging = false
    if (had_selection) {
        state.selection_changed = true
        state.selection_revision++
    }
}

def public text_source_view_request_copy(var state : TextSourceViewState) {
    //! Request semantic copy; the host decides which input invokes it.
    state.selection_copy_pending = true
}

def public text_source_view_select_all(document : TextSourceDocument const;
                                       var state : TextSourceViewState) {
    state.anchor_byte = 0
    state.focus_byte = length(document.source)
    state.selection_changed = true
    state.selection_revision++
    state.selection_commit_revision++
}

def public text_source_view_invalidate(var state : TextSourceViewState) {
    delete state.layout.lines
    delete state.layout.fragments
    delete state.cells
    state.layout_valid = false
    state.key = TextSourceLayoutKey()
    text_source_view_clear_selection(state)
}

def public text_source_view_dispose(var state : TextSourceViewState) {
    text_source_view_invalidate(state)
    state = TextSourceViewState()
}

def private style_id(span : TextSourceSpan const) : int {
    return span.styles.marker ? SOURCE_STYLE_MARKER : SOURCE_STYLE_REGULAR
}

def private range_columns(source : string; start_byte, end_byte, tab_cells : int) : int {
    if (end_byte <= start_byte) return 0
    var value := slice(source, start_byte, end_byte)
    var graphemes <- text_graphemes(value)
    var columns = 0
    for (grapheme in graphemes) {
        columns += (grapheme.first_codepoint == 0x0009u
            ? max(tab_cells, 1) : text_grapheme_cell_width(grapheme))
    }
    delete graphemes
    return columns
}

def private range_width(source : string; start_byte, end_byte, tab_cells : int;
                        cell_width : float) : float {
    return float(range_columns(source, start_byte, end_byte, tab_cells)) * cell_width
}

def private rebuild_cells(document : TextSourceDocument const;
                          var state : TextSourceViewState;
                          var font : ImFont?) {
    delete state.cells
    for (fragment in state.layout.fragments) {
        if (fragment.is_control) continue
        var value := slice(document.source,
            fragment.source.start_byte, fragment.source.end_byte)
        var graphemes <- text_graphemes(value)
        var x = fragment.rect.x
        for (grapheme in graphemes) {
            let start_byte = fragment.source.start_byte + grapheme.source.start_byte
            let end_byte = fragment.source.start_byte + grapheme.source.end_byte
            let columns = (grapheme.first_codepoint == 0x0009u
                ? max(state.key.tab_cells, 1) : text_grapheme_cell_width(grapheme))
            let width = float(columns) * state.key.cell_width
            let natural_width = CalcTextSizeForFontRange(font, state.key.font_size,
                document.source, length(document.source), start_byte, end_byte).x
            state.cells |> push(TextSourceCell(
                source = TextSourceRange(start_byte = start_byte, end_byte = end_byte),
                style_id = fragment.style_id,
                line_index = fragment.line_index,
                rect = float4(x, fragment.rect.y, x + width, fragment.rect.w),
                columns = columns,
                natural_width = natural_width))
            x += width
        }
        delete graphemes
    }
}

def private ensure_layout(document : TextSourceDocument const;
                          var state : TextSourceViewState;
                          var style : TextSourceViewStyle;
                          available_width : float;
                          var font : ImFont?) {
    let zoom = source_zoom(style)
    let font_size = (style.fonts.size_px > 0.0f
        ? style.fonts.size_px : GetFontSize()) * zoom
    let line_height = max(font_size, GetTextLineHeight() * font_size / max(GetFontSize(), 1.0f))
    let cell_width = max(1.0f,
        CalcTextSizeForFontRange(font, font_size, "M", 1, 0, 1).x)
    let max_width = style.wrap ? max(available_width, cell_width) : 100000000.0f
    var key = TextSourceLayoutKey(
        document_revision = document.revision,
        max_width = max_width,
        font_size = font_size,
        line_height = line_height,
        cell_width = cell_width,
        font_id = unsafe(reinterpret<uint64>(font)),
        wrap = style.wrap,
        tab_cells = max(style.tab_cells, 1))
    if (state.layout_valid && same_layout_key(state.key, key)) {
        state.layout_hits++
        return
    }
    delete state.layout.lines
    delete state.layout.fragments
    var spans : array<TextFlowSpan>
    for (span in document.spans) {
        spans |> push(TextFlowSpan(source = span.source, style_id = style_id(span)))
    }
    state.layout <- layout_text_flow_styled_ranges(document.source, spans,
        key.max_width, key.line_height) $(text : string;
          start_byte, end_byte, measured_style : int) : float {
            return range_width(text, start_byte, end_byte,
                               key.tab_cells, key.cell_width)
        }
    delete spans
    state.key = key
    state.layout_valid = true
    rebuild_cells(document, state, font)
    state.layout_misses++
}

def private line_for_y(state : TextSourceViewState const; y : float) : int {
    for (i in range(length(state.layout.lines))) {
        let line = state.layout.lines[i]
        if (y >= line.y && y <= line.y + line.height) return i
    }
    return -1
}

def private caret_for_byte(state : TextSourceViewState const; byte_offset : int) : TextFlowHit {
    for (cell_index in range(length(state.cells))) {
        let cell = state.cells[cell_index]
        if (byte_offset == cell.source.start_byte) {
            return TextFlowHit(valid = true, byte_offset = byte_offset,
                line_index = cell.line_index, fragment_index = cell_index,
                caret = float2(cell.rect.x, cell.rect.y),
                height = cell.rect.w - cell.rect.y)
        }
        if (byte_offset == cell.source.end_byte) {
            return TextFlowHit(valid = true, byte_offset = byte_offset,
                line_index = cell.line_index, fragment_index = cell_index,
                caret = float2(cell.rect.z, cell.rect.y),
                height = cell.rect.w - cell.rect.y, trailing = true)
        }
    }
    for (line_index in range(length(state.layout.lines))) {
        let line = state.layout.lines[line_index]
        if (byte_offset == line.source.start_byte || byte_offset == line.source.end_byte) {
            return TextFlowHit(valid = true, byte_offset = byte_offset,
                line_index = line_index, caret = float2(0.0f, line.y),
                height = line.height)
        }
    }
    return TextFlowHit()
}

def private hit_test(state : TextSourceViewState const; point : float2) : TextFlowHit {
    for (cell_index in range(length(state.cells))) {
        let cell = state.cells[cell_index]
        if (point.x < cell.rect.x || point.x > cell.rect.z
                || point.y < cell.rect.y || point.y > cell.rect.w) continue
        let trailing = point.x >= (cell.rect.x + cell.rect.z) * 0.5f
        return TextFlowHit(valid = true,
            byte_offset = trailing ? cell.source.end_byte : cell.source.start_byte,
            line_index = cell.line_index, fragment_index = cell_index,
            caret = float2(trailing ? cell.rect.z : cell.rect.x, cell.rect.y),
            height = cell.rect.w - cell.rect.y, trailing = trailing)
    }
    let line_index = line_for_y(state, point.y)
    if (line_index < 0) return TextFlowHit()
    let line = state.layout.lines[line_index]
    var first_cell = -1
    var last_cell = -1
    for (i in range(length(state.cells))) {
        if (state.cells[i].line_index != line_index) continue
        if (first_cell < 0) {
            first_cell = i
        }
        last_cell = i
    }
    if (first_cell < 0) {
        return TextFlowHit(valid = true, byte_offset = line.source.start_byte,
            line_index = line_index, caret = float2(0.0f, line.y), height = line.height)
    }
    let before = point.x <= state.cells[first_cell].rect.x
    let cell = before ? state.cells[first_cell] : state.cells[last_cell]
    return TextFlowHit(valid = true,
        byte_offset = before ? cell.source.start_byte : cell.source.end_byte,
        line_index = line_index, fragment_index = before ? first_cell : last_cell,
        caret = float2(before ? cell.rect.x : cell.rect.z, cell.rect.y),
        height = cell.rect.w - cell.rect.y, trailing = !before)
}

def private line_boundary(state : TextSourceViewState const;
                          byte_offset : int; end_ : bool) : int {
    let caret = caret_for_byte(state, byte_offset)
    if (!caret.valid || caret.line_index < 0
            || caret.line_index >= length(state.layout.lines)) return byte_offset
    let line = state.layout.lines[caret.line_index]
    return end_ ? line.source.end_byte : line.source.start_byte
}

def private vertical_byte(state : TextSourceViewState const;
                          byte_offset, direction : int) : int {
    let caret = caret_for_byte(state, byte_offset)
    if (!caret.valid) return byte_offset
    let target_line = caret.line_index + direction
    if (target_line < 0 || target_line >= length(state.layout.lines)) return byte_offset
    let line = state.layout.lines[target_line]
    let hit = hit_test(state, float2(caret.caret.x, line.y + line.height * 0.5f))
    return hit.valid ? hit.byte_offset : byte_offset
}

def private navigate(document : TextSourceDocument const;
                     var state : TextSourceViewState) {
    if (state.focus_byte < 0 || !IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
            || IsAnyItemActive()) return
    var action = 0
    if (IsKeyPressed(ImGuiKey.LeftArrow, false)) {
        action = 1
    } elif (IsKeyPressed(ImGuiKey.RightArrow, false)) {
        action = 2
    } elif (IsKeyPressed(ImGuiKey.UpArrow, false)) {
        action = 3
    } elif (IsKeyPressed(ImGuiKey.DownArrow, false)) {
        action = 4
    } elif (IsKeyPressed(ImGuiKey.Home, false)) {
        action = 5
    } elif (IsKeyPressed(ImGuiKey.End, false)) {
        action = 6
    }
    if (action == 0) return
    let io & = unsafe(GetIO())
    let selected = selected_source(state)
    let has_selection = selected.end_byte > selected.start_byte
    var next = state.focus_byte
    if (has_selection && !io.KeyShift && (action == 1 || action == 2)) {
        next = action == 1 ? selected.start_byte : selected.end_byte
        state.anchor_byte = next
    } elif (action == 1) {
        next = text_previous_grapheme_boundary(document.source, state.focus_byte)
    } elif (action == 2) {
        next = text_next_grapheme_boundary(document.source, state.focus_byte)
    } elif (action == 3 || action == 4) {
        next = vertical_byte(state, state.focus_byte, action == 3 ? -1 : 1)
    } else {
        next = line_boundary(state, state.focus_byte, action == 6)
    }
    if (!io.KeyShift) {
        state.anchor_byte = next
    }
    if (next != state.focus_byte || (has_selection && !io.KeyShift)) {
        state.focus_byte = next
        state.selection_changed = true
        state.selection_revision++
        state.navigation_revision++
    }
}

def private include_selection_rect(var state : TextSourceViewState; rect : float4) {
    if (!state.selection_screen_valid) {
        state.selection_screen_bounds = rect
        state.selection_screen_valid = true
    } else {
        state.selection_screen_bounds.x = min(state.selection_screen_bounds.x, rect.x)
        state.selection_screen_bounds.y = min(state.selection_screen_bounds.y, rect.y)
        state.selection_screen_bounds.z = max(state.selection_screen_bounds.z, rect.z)
        state.selection_screen_bounds.w = max(state.selection_screen_bounds.w, rect.w)
    }
}

def private selection_styles(document : TextSourceDocument const;
                             selection : TextSourceRange const) : TextSourceSelectionStyles {
    var result : TextSourceSelectionStyles
    var regular = false
    var markers = false
    for (span in document.spans) {
        if (span.source.end_byte <= selection.start_byte
                || span.source.start_byte >= selection.end_byte) continue
        markers = markers || span.styles.marker
        regular = regular || !span.styles.marker
    }
    result.all_regular = regular && !markers
    result.has_markers = markers
    result.has_mixed_styles = regular && markers
    return result
}

def public text_source_view(id : string; document : TextSourceDocument const;
                            var state : TextSourceViewState;
                            var style : TextSourceViewStyle) : TextSourceViewResult {
    var result = TextSourceViewResult()
    var fallback = GetFont()
    var font = source_font(style, fallback)
    let available = max(GetContentRegionAvail().x, 1.0f)
    ensure_layout(document, state, style, available, font)
    state.render_revision++
    state.selection_changed = false
    state.selection_screen_valid = false
    state.caret_screen_valid = false

    let origin = GetCursorScreenPos()
    state.screen_origin = origin
    state.screen_size = float2(max(available, state.layout.size.x),
        max(state.key.line_height, state.layout.size.y))
    PushID(id)
    Dummy(state.screen_size)

    let local_mouse = GetMousePos() - origin
    let hit = hit_test(state, local_mouse)
    if (hit.valid && IsWindowHovered(ImGuiHoveredFlags.None)
            && IsMouseClicked(ImGuiMouseButton.Left, false)) {
        state.anchor_byte = hit.byte_offset
        state.focus_byte = hit.byte_offset
        state.selection_dragging = true
        state.selection_changed = true
        state.selection_revision++
    } elif (hit.valid && state.selection_dragging && IsMouseDown(ImGuiMouseButton.Left)) {
        if (state.focus_byte != hit.byte_offset) {
            state.focus_byte = hit.byte_offset
            state.selection_changed = true
            state.selection_revision++
        }
    }
    if (state.selection_dragging && IsMouseReleased(ImGuiMouseButton.Left)) {
        state.selection_dragging = false
        state.selection_commit_revision++
    }

    navigate(document, state)
    let selection = selected_source(state)
    let has_selection = (selection.start_byte >= 0
        && selection.end_byte > selection.start_byte)
    var dl = GetWindowDrawList()
    let zoom = source_zoom(style)
    let window_pos = GetWindowPos()
    let window_size = GetWindowSize()
    let visible_min = window_pos
    let visible_max = window_pos + window_size
    for (cell in state.cells) {
        let p0 = origin + float2(cell.rect.x, cell.rect.y)
        let p1 = origin + float2(cell.rect.z, cell.rect.w)
        if (p1.x < visible_min.x || p0.x > visible_max.x
                || p1.y < visible_min.y || p0.y > visible_max.y) continue
        let selected = (has_selection
            && cell.source.end_byte > selection.start_byte
            && cell.source.start_byte < selection.end_byte)
        if (selected) {
            let rect = float4(p0.x, p0.y, p1.x, p1.y)
            *dl |> AddRectFilled(p0, p1, GetColorU32(style.selection_color),
                                 1.0f * zoom, ImDrawFlags.None)
            include_selection_rect(state, rect)
            if (IsMouseReleased(ImGuiMouseButton.Right)
                    && IsMouseHoveringRect(p0, p1, true)) {
                result.selection_context_requested = true
                result.selection_context_pos = GetMousePos()
                state.selection_context_pos = result.selection_context_pos
                state.selection_context_revision++
            }
        }
        let draw_x = p0.x + max(0.0f,
            (p1.x - p0.x - cell.natural_width) * 0.5f)
        let color = (cell.style_id == SOURCE_STYLE_MARKER
            ? style.marker_color : style.text_color)
        *dl |> PushClipRect(p0, p1, true)
        *dl |> AddTextRange(font, state.key.font_size,
            float2(draw_x, p0.y), GetColorU32(color),
            document.source, length(document.source),
            cell.source.start_byte, cell.source.end_byte)
        if (cell.style_id == SOURCE_STYLE_MARKER) {
            *dl |> AddTextRange(font, state.key.font_size,
                float2(draw_x + max(0.5f, 0.35f * zoom), p0.y), GetColorU32(color),
                document.source, length(document.source),
                cell.source.start_byte, cell.source.end_byte)
        }
        *dl |> PopClipRect()
    }

    if (state.focus_byte >= 0) {
        let caret = caret_for_byte(state, state.focus_byte)
        if (caret.valid) {
            let top = origin + caret.caret
            state.caret_screen_valid = true
            state.caret_screen_pos = top
            state.caret_screen_height = caret.height
            state.selection_screen_anchor = float2(top.x, top.y + caret.height)
            if (!has_selection && IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)) {
                *dl |> AddLine(top, float2(top.x, top.y + caret.height),
                               GetColorU32(style.caret_color), max(1.0f, zoom))
            }
        }
    }

    let copy_requested = state.selection_copy_pending
    state.selection_copy_pending = false
    if (has_selection && copy_requested) {
        result.selection_copy_requested = true
        result.selection_copy_text := slice(document.source,
            selection.start_byte, selection.end_byte)
        state.selection_copy_text := result.selection_copy_text
        state.selection_copy_revision++
        if (style.write_system_clipboard) {
            result.selection_copied = (clipboard_set_text(result.selection_copy_text)
                == ClipboardStatus.ok)
        }
    }

    result.selection_changed = state.selection_changed
    result.selection = TextSourceSelection(
        active = has_selection,
        source = selection,
        styles = selection_styles(document, selection),
        screen_valid = state.selection_screen_valid,
        screen_bounds = state.selection_screen_bounds,
        screen_anchor = state.selection_screen_anchor)
    PopID()
    return <- result
}
