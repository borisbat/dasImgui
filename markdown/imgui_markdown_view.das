options gen2
options indenting = 4
options no_unused_function_arguments = false

module imgui_markdown_view shared

require imgui public
require imgui/imgui_markdown_model public
require imgui/imgui_text_flow
require imgui/imgui_fonts public
require imgui/imgui_icons
require daslib/clipboard
require math
require strings

//! Immediate-mode rendering counterpart to `imgui_markdown_model`.
//!
//! The document and inline-run model remain UI-independent. This layer owns
//! wrapping, colors, hover/click/copy behavior, and block chrome. Link actions
//! are returned to the host; the viewer never opens a URI on its own.

struct public MarkdownViewStyle {
    fonts : FontRoleSet = FontRoleSet()
    zoom : float = 1.0f
    text_color : float4 = float4(0.86f, 0.87f, 0.89f, 1.0f)
    strong_color : float4 = float4(0.97f, 0.89f, 0.68f, 1.0f)
    emphasis_color : float4 = float4(0.77f, 0.84f, 0.94f, 1.0f)
    link_color : float4 = float4(0.36f, 0.68f, 1.0f, 1.0f)
    link_hover_color : float4 = float4(0.55f, 0.80f, 1.0f, 1.0f)
    code_color : float4 = float4(0.94f, 0.80f, 0.55f, 1.0f)
    code_background : float4 = float4(0.10f, 0.11f, 0.14f, 1.0f)
    selection_color : float4 = float4(0.24f, 0.48f, 0.78f, 0.55f)
    quote_color : float4 = float4(0.42f, 0.47f, 0.56f, 1.0f)
    marker_color : float4 = float4(0.70f, 0.73f, 0.78f, 1.0f)
    heading_color : float4 = float4(0.96f, 0.96f, 0.97f, 1.0f)
    block_spacing : float = 8.0f
    paragraph_spacing : float = 5.0f
    quote_indent : float = 16.0f
    code_padding : float = 8.0f
    copy_icon_size : float = 14.0f
    show_link_copy : bool = true
}

struct public MarkdownSelection {
    active : bool = false
    source : TextSourceRange = TextSourceRange(start_byte = -1, end_byte = -1)
    styles : MdSelectionStyles
    screen_valid : bool = false
    screen_bounds : float4
    screen_anchor : float2
}

struct public MarkdownViewResult {
    hovered : bool = false
    activated : bool = false
    copied : bool = false
    hovered_node : int = -1
    activated_node : int = -1
    copied_node : int = -1
    source : TextSourceRange = TextSourceRange(start_byte = -1, end_byte = -1)
    target : string
    selection : MarkdownSelection = MarkdownSelection()
    selection_changed : bool = false
    selection_copied : bool = false
    selection_context_requested : bool = false
    selection_context_pos : float2
}

struct public MarkdownLayoutKey {
    max_width : float
    line_height : float
    font_size : float
    icon_size : float2
    forced_style : int
    show_link_copy : bool
    regular_id : uint64 = 0uL
    bold_id : uint64 = 0uL
    italic_id : uint64 = 0uL
    bold_italic_id : uint64 = 0uL
    monospace_id : uint64 = 0uL
    fallback_id : uint64 = 0uL
}

struct public MarkdownNodeViewCache {
    content_valid : bool = false
    content : MdInlineContent
    marker_valid : bool = false
    marker : string
    layout_valid : bool = false
    layout_key : MarkdownLayoutKey = MarkdownLayoutKey()
    layout : TextFlowLayout
    //! Last screen-space placement of this cached layout.  This is telemetry,
    //! not part of the layout key: scrolling moves the placement without
    //! invalidating or rebuilding the layout.
    screen_origin : float2
    screen_revision : int = -1
}

struct public MarkdownViewState {
    //! One state belongs to one immutable document revision. Bump the caller's
    //! revision whenever the document is reparsed or otherwise replaced.
    document_revision : int = -1
    node_count : int = 0
    nodes : array<MarkdownNodeViewCache>
    content_hits : int = 0
    content_misses : int = 0
    layout_hits : int = 0
    layout_misses : int = 0
    selection_anchor : MdTextPosition = MdTextPosition()
    selection_focus : MdTextPosition = MdTextPosition()
    selection_dragging : bool = false
    selection_dragged : bool = false
    selection_pressed_semantic : int = -1
    selection_changed : bool = false
    selection_click_claimed : bool = false
    selection_screen_valid : bool = false
    selection_screen_bounds : float4
    selection_screen_anchor : float2
    //! Monotonic event acknowledgements used by live inspection and tests.
    //! They describe observed UI state; callers never need to wait a number
    //! of frames before issuing the next input event.
    render_revision : int = 0
    hover_revision : int = 0
    hovered_inline_node : int = -1
    hovered_fragment : int = -1
    hovered_display_byte : int = -1
    selection_revision : int = 0
    selection_commit_revision : int = 0
    selection_copy_revision : int = 0
    selection_context_revision : int = 0
    selection_context_pos : float2
    navigation_revision : int = 0
    caret_screen_valid : bool = false
    caret_screen_pos : float2
    caret_screen_height : float = 0.0f
    navigation_goal_x_valid : bool = false
    navigation_goal_x : float = 0.0f
    navigation_needs_scroll : bool = false
    navigation_scroll_revision : int = 0
    navigation_scroll_target : float = 0.0f
    viewport_top : float = 0.0f
    viewport_bottom : float = 0.0f
}

let private STYLE_STRONG = 1
let private STYLE_EMPHASIS = 2
let private STYLE_CODE = 4
let private STYLE_STRIKE = 8
let private STYLE_LINK = 16
let private STYLE_HEADING = 32

def private clear_node_cache(var entry : MarkdownNodeViewCache) {
    delete entry.content.runs
    delete entry.layout.lines
    delete entry.layout.fragments
    entry = MarkdownNodeViewCache()
}

def private clear_selection(var state : MarkdownViewState) {
    state.selection_anchor = MdTextPosition()
    state.selection_focus = MdTextPosition()
    state.selection_dragging = false
    state.selection_dragged = false
    state.selection_pressed_semantic = -1
    state.selection_screen_valid = false
}

def public markdown_view_clear_selection(var state : MarkdownViewState) {
    //! Clear selection explicitly and acknowledge the state transition.  Live
    //! tooling uses the revision rather than a frame delay to observe it.
    let had_state = (state.selection_anchor.valid
        || state.selection_focus.valid || state.selection_dragging)
    clear_selection(state)
    if (had_state) {
        state.selection_revision++
        state.selection_changed = true
    }
}

def public markdown_view_invalidate(var state : MarkdownViewState) {
    //! Deterministically release all retained strings and arrays. The outer
    //! cache capacity is retained for a same-sized replacement document.
    for (i in range(length(state.nodes))) {
        var entry & = unsafe(state.nodes[i])
        clear_node_cache(entry)
    }
    state.document_revision = -1
    state.node_count = 0
    clear_selection(state)
}

def public markdown_view_dispose(var state : MarkdownViewState) {
    //! Release a caller-owned view state during application shutdown.
    markdown_view_invalidate(state)
    unsafe { delete state.nodes }
    state = MarkdownViewState()
}

def private prepare_view_state(doc : MdDocument const;
                               var state : MarkdownViewState;
                               document_revision : int) {
    let count = length(doc.nodes)
    if (state.document_revision == document_revision
            && state.node_count == count && length(state.nodes) == count) return
    markdown_view_invalidate(state)
    if (length(state.nodes) != count) {
        unsafe {
            delete state.nodes
            state.nodes |> resize(count)
        }
    }
    state.document_revision = document_revision
    state.node_count = count
}

def private ensure_inline(doc : MdDocument const; node_index : int;
                          var state : MarkdownViewState) {
    var entry & = unsafe(state.nodes[node_index])
    if (!entry.content_valid) {
        entry.content <- md_inline_content(doc, node_index)
        entry.content_valid = true
        state.content_misses++
    } else {
        state.content_hits++
    }
}

def private view_zoom(style : MarkdownViewStyle const) : float {
    return clamp(style.zoom, 0.5f, 3.0f)
}

def private zoomed(style : MarkdownViewStyle const; value : float) : float {
    return value * view_zoom(style)
}

def private run_style(run : MdInlineRun const) : int {
    var value = 0
    if (run.is_strong) {
        value += STYLE_STRONG
    }
    if (run.is_emphasis) {
        value += STYLE_EMPHASIS
    }
    if (run.is_code) {
        value += STYLE_CODE
    }
    if (run.is_strikethrough) {
        value += STYLE_STRIKE
    }
    if (run.is_link) {
        value += STYLE_LINK
    }
    return value
}

def private has_style(value, flag : int) : bool {
    return (value & flag) != 0
}

def private font_for_style(style_id : int; var roles : FontRoleSet;
                           var fallback : ImFont?) : ImFont? {
    if (has_style(style_id, STYLE_CODE) && roles.monospace != null) {
        return roles.monospace
    }
    let bold_role = (has_style(style_id, STYLE_STRONG)
        || has_style(style_id, STYLE_HEADING))
    if (bold_role
            && has_style(style_id, STYLE_EMPHASIS)
            && roles.bold_italic != null) {
        return roles.bold_italic
    }
    if (bold_role && roles.bold != null) {
        return roles.bold
    }
    if (has_style(style_id, STYLE_EMPHASIS) && roles.italic != null) {
        return roles.italic
    }
    if (roles.regular != null) return roles.regular
    return fallback
}

def private fragment_min(origin : float2; fragment : TextFlowFragment const) : float2 {
    return origin + float2(fragment.rect.x, fragment.rect.y)
}

def private fragment_max(origin : float2; fragment : TextFlowFragment const) : float2 {
    return origin + float2(fragment.rect.z, fragment.rect.w)
}

def private run_semantic_id(doc : MdDocument const; run : MdInlineRun const;
                            run_index : int) : int {
    if (!run.is_link) return -1
    return run.semantic_node >= 0 ? run.semantic_node : length(doc.nodes) + run_index
}

def private link_run_index(doc : MdDocument const; content : MdInlineContent const;
                           semantic_id : int) : int {
    for (i in range(length(content.runs))) {
        if (run_semantic_id(doc, content.runs[i], i) == semantic_id) return i
    }
    return -1
}

def private link_target(doc : MdDocument const; content : MdInlineContent const;
                        semantic_id : int) : string {
    let index = link_run_index(doc, content, semantic_id)
    if (index < 0) return ""
    return content.runs[index].destination
}

def private selected_source(state : MarkdownViewState const) : TextSourceRange {
    return md_text_selection_range(state.selection_anchor, state.selection_focus)
}

def private same_text_position(a, b : MdTextPosition const) : bool {
    return (a.valid == b.valid && a.inline_node == b.inline_node
        && a.display_byte == b.display_byte && a.source_byte == b.source_byte
        && a.trailing == b.trailing)
}

def private adjacent_text_position(var state : MarkdownViewState;
                                   from : MdTextPosition const;
                                   direction : int) : MdTextPosition {
    if (!from.valid || from.inline_node < 0
            || from.inline_node >= length(state.nodes)) return MdTextPosition()
    let content & = unsafe(state.nodes[from.inline_node].content)
    if (direction < 0 && from.display_byte > 0) {
        let at = text_previous_grapheme_boundary(content.text, from.display_byte)
        return md_inline_position(content, from.inline_node, at, false)
    }
    if (direction > 0 && from.display_byte < length(content.text)) {
        let at = text_next_grapheme_boundary(content.text, from.display_byte)
        return md_inline_position(content, from.inline_node, at, true)
    }
    var node = from.inline_node + direction
    while (node >= 0 && node < length(state.nodes)) {
        let entry & = unsafe(state.nodes[node])
        if (entry.content_valid && entry.layout_valid && !empty(entry.content.text)) {
            let at = direction < 0 ? length(entry.content.text) : 0
            return md_inline_position(entry.content, node, at, direction < 0)
        }
        node += direction
    }
    return from
}

def private position_line_index(entry : MarkdownNodeViewCache const;
                                position : MdTextPosition const) : int {
    for (fragment in entry.layout.fragments) {
        if (position_in_fragment(position, position.inline_node, fragment)) {
            return fragment.line_index
        }
    }
    return -1
}

def private line_boundary_position(var state : MarkdownViewState;
                                   from : MdTextPosition const;
                                   end_ : bool) : MdTextPosition {
    if (!from.valid || from.inline_node < 0
            || from.inline_node >= length(state.nodes)) return from
    let entry & = unsafe(state.nodes[from.inline_node])
    let line_index = position_line_index(entry, from)
    if (line_index < 0 || line_index >= length(entry.layout.lines)) return from
    let line = entry.layout.lines[line_index]
    let at = end_ ? line.source.end_byte : line.source.start_byte
    return md_inline_position(entry.content, from.inline_node, at, end_)
}

def private line_text_x_range(entry : MarkdownNodeViewCache const;
                              line_index : int) : float2 {
    var result = float2(0.0f, 0.0f)
    var valid = false
    for (fragment in entry.layout.fragments) {
        if (fragment.line_index != line_index || fragment.is_control) continue
        if (!valid) {
            result = float2(fragment.rect.x, fragment.rect.z)
            valid = true
        } else {
            result.x = min(result.x, fragment.rect.x)
            result.y = max(result.y, fragment.rect.z)
        }
    }
    return result
}

def private vertical_text_position(var state : MarkdownViewState;
                                   var style : MarkdownViewStyle;
                                   from : MdTextPosition const;
                                   direction : int) : MdTextPosition {
    if (!from.valid || from.inline_node < 0
            || from.inline_node >= length(state.nodes)) return from
    let current & = unsafe(state.nodes[from.inline_node])
    let current_line_index = position_line_index(current, from)
    if (current_line_index < 0) return from
    let current_line = current.layout.lines[current_line_index]
    let current_y = (current.screen_origin.y + current_line.y
        + current_line.height * 0.5f)
    let goal_x = (state.navigation_goal_x_valid
        ? state.navigation_goal_x : state.caret_screen_pos.x)
    var best_node = -1
    var best_line = -1
    var best_y = direction < 0 ? -1000000000.0f : 1000000000.0f
    var best_x_distance = 1000000000.0f
    for (node_index in range(length(state.nodes))) {
        let entry & = unsafe(state.nodes[node_index])
        if (!entry.content_valid || !entry.layout_valid
                || entry.screen_revision < state.render_revision - 1) continue
        for (line_index in range(length(entry.layout.lines))) {
            let line = entry.layout.lines[line_index]
            let line_y = entry.screen_origin.y + line.y + line.height * 0.5f
            if ((direction < 0 && line_y >= current_y - 0.5f)
                    || (direction > 0 && line_y <= current_y + 0.5f)) continue
            let xr = line_text_x_range(entry, line_index)
            if (xr.y <= xr.x) continue
            let screen_x0 = entry.screen_origin.x + xr.x
            let screen_x1 = entry.screen_origin.x + xr.y
            let x_distance = (goal_x < screen_x0 ? screen_x0 - goal_x
                : (goal_x > screen_x1 ? goal_x - screen_x1 : 0.0f))
            let nearer_y = direction < 0 ? line_y > best_y : line_y < best_y
            let same_y = abs(line_y - best_y) < 0.5f
            if (nearer_y || (same_y && x_distance < best_x_distance)) {
                best_node = node_index
                best_line = line_index
                best_y = line_y
                best_x_distance = x_distance
            }
        }
    }
    if (best_node < 0) return from
    let target & = unsafe(state.nodes[best_node])
    let target_line = target.layout.lines[best_line]
    let xr = line_text_x_range(target, best_line)
    let local_x = clamp(goal_x - target.screen_origin.x, xr.x, xr.y)
    let hit = text_flow_hit_test_ranges(target.content.text, target.layout,
        float2(local_x, target_line.y + target_line.height * 0.5f)) $(text : string;
          start_byte, end_byte, style_id : int) : float {
            var fallback = GetFont()
            var font = font_for_style(style_id, style.fonts, fallback)
            return CalcTextSizeForFontRange(font, target.layout_key.font_size,
                text, length(text), start_byte, end_byte).x
        }
    if (!hit.valid || hit.line_index != best_line) return from
    return md_inline_position(target.content, best_node,
                              hit.byte_offset, hit.trailing)
}

def private navigate_selection_keyboard(var state : MarkdownViewState;
                                        var style : MarkdownViewStyle) {
    if (!state.selection_focus.valid
            || !IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
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
    let selection_range = selected_source(state)
    let has_selection = selection_range.end_byte > selection_range.start_byte
    var next = state.selection_focus
    if (has_selection && !io.KeyShift && (action == 1 || action == 2)) {
        if (action == 1) {
            next = (state.selection_anchor.source_byte <= state.selection_focus.source_byte
                ? state.selection_anchor : state.selection_focus)
        } else {
            next = (state.selection_anchor.source_byte >= state.selection_focus.source_byte
                ? state.selection_anchor : state.selection_focus)
        }
        state.selection_anchor = next
    } else {
        if (action == 1 || action == 2) {
            next = adjacent_text_position(state, state.selection_focus,
                                          action == 1 ? -1 : 1)
        } elif (action == 3 || action == 4) {
            if (!state.navigation_goal_x_valid) {
                state.navigation_goal_x = state.caret_screen_pos.x
                state.navigation_goal_x_valid = true
            }
            next = vertical_text_position(state, style, state.selection_focus,
                                          action == 3 ? -1 : 1)
        } else {
            next = line_boundary_position(state, state.selection_focus, action == 6)
        }
        if (!io.KeyShift) {
            state.selection_anchor = next
        }
    }
    if (action != 3 && action != 4) {
        state.navigation_goal_x_valid = false
    }
    if (!same_text_position(state.selection_focus, next)) {
        state.selection_focus = next
        state.selection_revision++
        state.navigation_revision++
        state.selection_changed = true
        state.navigation_needs_scroll = true
    } elif (has_selection && !io.KeyShift) {
        state.selection_focus = next
        state.selection_revision++
        state.navigation_revision++
        state.selection_changed = true
        state.navigation_needs_scroll = true
    }
}

def private ensure_keyboard_caret_visible(var state : MarkdownViewState) {
    if (!state.navigation_needs_scroll) return
    state.navigation_needs_scroll = false
    if (!state.caret_screen_valid) return
    let caret_top = state.caret_screen_pos.y
    let caret_bottom = caret_top + state.caret_screen_height
    let old_scroll = GetScrollY()
    var target = old_scroll
    if (caret_top < state.viewport_top) {
        target = old_scroll - (state.viewport_top - caret_top)
    } elif (caret_bottom > state.viewport_bottom) {
        target = old_scroll + (caret_bottom - state.viewport_bottom)
    }
    target = clamp(target, 0.0f, GetScrollMaxY())
    if (abs(target - old_scroll) > 0.5f) {
        SetScrollY(target)
        state.navigation_scroll_target = target
        state.navigation_scroll_revision++
    }
}

def private selected_display(run : MdInlineRun const;
                             source : TextSourceRange const) : TextSourceRange {
    let a = max(source.start_byte, run.source.start_byte)
    let b = min(source.end_byte, run.source.end_byte)
    if (run.source.start_byte < 0 || b <= a) {
        return TextSourceRange(start_byte = -1, end_byte = -1)
    }
    let display_size = run.display.end_byte - run.display.start_byte
    let source_size = run.source.end_byte - run.source.start_byte
    if (run.source_exact && display_size == source_size) {
        return TextSourceRange(
            start_byte = run.display.start_byte + a - run.source.start_byte,
            end_byte = run.display.start_byte + b - run.source.start_byte)
    }
    // Entities and other transformed runs are indivisible in source space.
    return run.display
}

def private include_selection_screen_rect(var state : MarkdownViewState;
                                          rect : float4) {
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

def private position_in_fragment(position : MdTextPosition const; node_index : int;
                                 fragment : TextFlowFragment const) : bool {
    if (!position.valid || position.inline_node != node_index || fragment.is_control) return false
    if (position.trailing) {
        return (fragment.source.start_byte < position.display_byte
            && position.display_byte <= fragment.source.end_byte)
    }
    return (fragment.source.start_byte <= position.display_byte
        && position.display_byte < fragment.source.end_byte)
}

def private same_layout_key(a, b : MarkdownLayoutKey) : bool {
    return (a.max_width == b.max_width && a.line_height == b.line_height
        && a.font_size == b.font_size
        && a.icon_size.x == b.icon_size.x && a.icon_size.y == b.icon_size.y
        && a.forced_style == b.forced_style
        && a.show_link_copy == b.show_link_copy
        && a.regular_id == b.regular_id && a.bold_id == b.bold_id
        && a.italic_id == b.italic_id && a.bold_italic_id == b.bold_italic_id
        && a.monospace_id == b.monospace_id && a.fallback_id == b.fallback_id)
}

def private ensure_layout(doc : MdDocument const; node_index : int;
                          var state : MarkdownViewState;
                          key : MarkdownLayoutKey;
                          var style : MarkdownViewStyle;
                          var fallback : ImFont?) {
    ensure_inline(doc, node_index, state)
    var entry & = unsafe(state.nodes[node_index])
    if (entry.layout_valid && same_layout_key(entry.layout_key, key)) {
        state.layout_hits++
        return
    }
    delete entry.layout.lines
    delete entry.layout.fragments
    var spans : array<TextFlowSpan>
    for (i in range(length(entry.content.runs))) {
        let run = entry.content.runs[i]
        let semantic_id = run_semantic_id(doc, run, i)
        let has_semantic = semantic_id >= 0
        let is_last_semantic = (has_semantic
            && (i + 1 >= length(entry.content.runs)
                || run_semantic_id(doc, entry.content.runs[i + 1], i + 1)
                    != semantic_id))
        spans |> push(TextFlowSpan(
            source = run.display,
            style_id = run_style(run) | key.forced_style,
            semantic_id = semantic_id,
            uri_wrap = run.is_link,
            trailing_control_id = key.show_link_copy && is_last_semantic
                ? semantic_id : -1,
            trailing_control_size = key.show_link_copy && is_last_semantic
                ? key.icon_size : float2(0.0f, 0.0f)))
    }
    entry.layout <- layout_text_flow_styled_ranges(entry.content.text, spans,
        key.max_width, key.line_height) $(text : string; start_byte : int; end_byte : int;
          style_id : int) : float {
            var font = font_for_style(style_id, style.fonts, fallback)
            return CalcTextSizeForFontRange(font, key.font_size, text,
                                            length(text), start_byte, end_byte).x
        }
    delete spans
    entry.layout_key = key
    entry.layout_valid = true
    state.layout_misses++
}

def private render_inline(doc : MdDocument const; node_index : int;
                          var state : MarkdownViewState; max_width : float;
                          var style : MarkdownViewStyle;
                          font_scale : float; forced_style : int;
                          var result : MarkdownViewResult) {
    let available = max(max_width, 1.0f)
    let base_size = (style.fonts.size_px > 0.0f
        ? style.fonts.size_px : GetFontSize())
    let zoom = view_zoom(style)
    let font_size = base_size * zoom * font_scale
    let line_height = GetTextLineHeight() * font_size / max(GetFontSize(), 1.0f)
    var fallback_font = GetFont()
    let icon_full = float2(
        style.copy_icon_size * zoom + GetStyle().FramePadding.x * 2.0f,
        style.copy_icon_size * zoom + GetStyle().FramePadding.y * 2.0f)
    var key = MarkdownLayoutKey(
        max_width = available, line_height = line_height, font_size = font_size,
        icon_size = icon_full, forced_style = forced_style,
        show_link_copy = style.show_link_copy,
        regular_id = unsafe(reinterpret<uint64>(style.fonts.regular)),
        bold_id = unsafe(reinterpret<uint64>(style.fonts.bold)),
        italic_id = unsafe(reinterpret<uint64>(style.fonts.italic)),
        bold_italic_id = unsafe(reinterpret<uint64>(style.fonts.bold_italic)),
        monospace_id = unsafe(reinterpret<uint64>(style.fonts.monospace)),
        fallback_id = unsafe(reinterpret<uint64>(fallback_font)))
    ensure_layout(doc, node_index, state, key, style, fallback_font)
    let content & = unsafe(state.nodes[node_index].content)
    let layout & = unsafe(state.nodes[node_index].layout)
    PushID(node_index)

    let origin = GetCursorScreenPos()
    var cache & = unsafe(state.nodes[node_index])
    cache.screen_origin = origin
    cache.screen_revision = state.render_revision
    Dummy(float2(available, max(layout.size.y, line_height)))

    var hovered = -1
    for (fragment in layout.fragments) {
        if (fragment.semantic_id >= 0 && IsMouseHoveringRect(
                fragment_min(origin, fragment), fragment_max(origin, fragment), true)) {
            hovered = fragment.semantic_id
        }
    }

    let hit = text_flow_hit_test_ranges(content.text, layout,
        GetMousePos() - origin) $(text : string; start_byte, end_byte, style_id : int) : float {
            var font = font_for_style(style_id, style.fonts, fallback_font)
            return CalcTextSizeForFontRange(font, font_size, text, length(text),
                                            start_byte, end_byte).x
        }
    let hit_visible = (hit.valid && hit.fragment_index >= 0
        && IsMouseHoveringRect(
            fragment_min(origin, layout.fragments[hit.fragment_index]),
            fragment_max(origin, layout.fragments[hit.fragment_index]), true))
    if (hit_visible) {
        state.hovered_inline_node = node_index
        state.hovered_fragment = hit.fragment_index
        state.hovered_display_byte = hit.byte_offset
        let position = md_inline_position(content, node_index, hit.byte_offset, hit.trailing)
        if (position.valid && IsMouseClicked(ImGuiMouseButton.Left, false)) {
            state.selection_anchor = position
            state.selection_focus = position
            state.selection_dragging = true
            state.selection_dragged = false
            state.selection_pressed_semantic = hovered
            state.selection_click_claimed = true
            state.selection_changed = true
            state.selection_revision++
        } elif (position.valid && state.selection_dragging
                && IsMouseDown(ImGuiMouseButton.Left)) {
            if (state.selection_focus.source_byte != position.source_byte
                    || state.selection_focus.inline_node != position.inline_node
                    || state.selection_focus.display_byte != position.display_byte) {
                state.selection_focus = position
                state.selection_changed = true
                state.selection_revision++
            }
            state.selection_dragged = (state.selection_anchor.source_byte
                != state.selection_focus.source_byte)
        }
    }
    if (hovered >= 0) {
        result.hovered = true
        result.hovered_node = hovered
        let run_index = link_run_index(doc, content, hovered)
        if (run_index >= 0) {
            result.hovered_node = content.runs[run_index].semantic_node
            result.source = content.runs[run_index].source
        }
        result.target := link_target(doc, content, hovered)
    }

    var dl = GetWindowDrawList()
    for (fragment in layout.fragments) {
        if (fragment.is_control) continue
        let p0 = fragment_min(origin, fragment)
        let p1 = fragment_max(origin, fragment)
        let hot_link = fragment.semantic_id >= 0 && fragment.semantic_id == hovered
        var color = style.text_color
        if (has_style(fragment.style_id, STYLE_LINK)) {
            color = hot_link ? style.link_hover_color : style.link_color
        } elif (has_style(fragment.style_id, STYLE_CODE)) {
            color = style.code_color
        } elif (has_style(fragment.style_id, STYLE_STRONG)) {
            color = style.strong_color
        } elif (has_style(fragment.style_id, STYLE_EMPHASIS)) {
            color = style.emphasis_color
        }
        var font = font_for_style(fragment.style_id, style.fonts, fallback_font)
        if (has_style(fragment.style_id, STYLE_CODE)) {
            *dl |> AddRectFilled(p0 - float2(2.0f * zoom, 0.0f),
                                 p1 + float2(2.0f * zoom, 0.0f),
                                 GetColorU32(style.code_background), 2.0f * zoom,
                                 ImDrawFlags.None)
        }

        let selection_source = selected_source(state)
        if (selection_source.start_byte >= 0
                && selection_source.end_byte > selection_source.start_byte) {
            for (run in content.runs) {
                let display = selected_display(run, selection_source)
                let a = max(display.start_byte, fragment.source.start_byte)
                let b = min(display.end_byte, fragment.source.end_byte)
                if (display.start_byte < 0 || b <= a) continue
                let prefix = CalcTextSizeForFontRange(font, font_size, content.text,
                    length(content.text), fragment.source.start_byte, a).x
                let width = CalcTextSizeForFontRange(font, font_size, content.text,
                    length(content.text), a, b).x
                let selection_rect = float4(
                    p0.x + prefix, p0.y, p0.x + prefix + width, p1.y)
                *dl |> AddRectFilled(
                    float2(selection_rect.x, selection_rect.y),
                    float2(selection_rect.z, selection_rect.w),
                    GetColorU32(style.selection_color), 1.5f * zoom,
                    ImDrawFlags.None)
                include_selection_screen_rect(state, selection_rect)
                if (IsMouseReleased(ImGuiMouseButton.Right)
                        && IsMouseHoveringRect(
                            float2(selection_rect.x, selection_rect.y),
                            float2(selection_rect.z, selection_rect.w), true)) {
                    result.selection_context_requested = true
                    result.selection_context_pos = GetMousePos()
                    state.selection_context_pos = result.selection_context_pos
                    state.selection_context_revision++
                }
            }
        }
        if (position_in_fragment(state.selection_focus, node_index, fragment)) {
            let caret_byte = clamp(state.selection_focus.display_byte,
                fragment.source.start_byte, fragment.source.end_byte)
            let caret_x = CalcTextSizeForFontRange(font, font_size, content.text,
                length(content.text), fragment.source.start_byte, caret_byte).x
            let caret_top = float2(p0.x + caret_x, p0.y)
            state.selection_screen_anchor = float2(caret_top.x, p1.y)
            state.caret_screen_valid = true
            state.caret_screen_pos = caret_top
            state.caret_screen_height = p1.y - p0.y
            if (selection_source.start_byte == selection_source.end_byte
                    && IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)) {
                *dl |> AddLine(caret_top, float2(caret_top.x, p1.y),
                               GetColorU32(style.text_color), max(1.0f, zoom))
            }
        }
        *dl |> AddTextRange(font, font_size, p0, GetColorU32(color),
                           content.text, length(content.text), fragment.source.start_byte,
                           fragment.source.end_byte)
        if (hot_link) {
            let y = p0.y + line_height - max(1.0f, zoom)
            *dl |> AddLine(float2(p0.x, y), float2(p1.x, y),
                           GetColorU32(color), max(1.0f, zoom))
        }
        if (has_style(fragment.style_id, STYLE_STRIKE)) {
            let y = p0.y + line_height * 0.52f
            *dl |> AddLine(float2(p0.x, y), float2(p1.x, y),
                           GetColorU32(color), max(1.0f, zoom))
        }
    }

    if (hovered >= 0) {
        SetMouseCursor(ImGuiMouseCursor.Hand)
        if (IsMouseReleased(ImGuiMouseButton.Left)
                && state.selection_pressed_semantic == hovered
                && !state.selection_dragged) {
            let run_index = link_run_index(doc, content, hovered)
            result.activated = true
            result.activated_node = (run_index >= 0
                ? content.runs[run_index].semantic_node : -1)
            if (run_index >= 0) {
                result.source = content.runs[run_index].source
            }
            result.target := link_target(doc, content, hovered)
        }
    }
    for (fragment in layout.fragments) {
        if (!fragment.is_control) continue
        let visible = fragment.control_id == hovered
        if (icon_button_draw_at("##markdown_copy_{fragment.control_id}", "duplicate",
                                fragment_min(origin, fragment),
                                style.copy_icon_size * zoom, 1.0f, visible)) {
            let control_id = fragment.control_id
            if (control_id >= 0) {
                let run_index = link_run_index(doc, content, control_id)
                let target = link_target(doc, content, control_id)
                if (clipboard_set_text(target) == ClipboardStatus.ok) {
                    result.copied = true
                    result.copied_node = (run_index >= 0
                        ? content.runs[run_index].semantic_node : -1)
                    if (run_index >= 0) {
                        result.source = content.runs[run_index].source
                    }
                    result.target := target
                }
            }
        }
        if (visible && IsItemHovered()) SetTooltip("Copy URI")
    }
    PopID()
}

def private block_spacing(var style : MarkdownViewStyle; amount : float) {
    if (amount > 0.0f) Dummy(float2(0.0f, zoomed(style, amount)))
}

def private render_children(doc : MdDocument const; node_index : int;
                            var state : MarkdownViewState;
                            var style : MarkdownViewStyle;
                            var result : MarkdownViewResult) {
    var child = doc.nodes[node_index].first_child
    while (child >= 0) {
        render_block(doc, child, state, style, result)
        child = doc.nodes[child].next_sibling
    }
}

def private render_list(doc : MdDocument const; node_index : int;
                        var state : MarkdownViewState;
                        var style : MarkdownViewStyle;
                        var result : MarkdownViewResult) {
    let list = doc.nodes[node_index]
    var item = list.first_child
    var ordinal = list.start_number > 0 ? list.start_number : 1
    while (item >= 0) {
        let node = doc.nodes[item]
        var cache & = unsafe(state.nodes[item])
        if (!cache.marker_valid) {
            cache.marker = list.kind == MdNodeKind.ordered_list ? "{ordinal}." : "•"
            if (node.is_task) {
                cache.marker = node.is_checked ? "☑" : "☐"
            }
            cache.marker_valid = true
        }
        TextColored(style.marker_color, cache.marker)
        SameLine(0.0f, GetStyle().ItemInnerSpacing.x)
        var child = node.first_child
        while (child >= 0) {
            render_block(doc, child, state, style, result)
            child = doc.nodes[child].next_sibling
        }
        item = node.next_sibling
        ordinal++
    }
    block_spacing(style, list.is_tight ? 2.0f : style.block_spacing)
}

def private render_table_section(doc : MdDocument const;
                                 section_index : int; headers : bool;
                                 var state : MarkdownViewState;
                                 var style : MarkdownViewStyle;
                                 var result : MarkdownViewResult) {
    var row = doc.nodes[section_index].first_child
    while (row >= 0) {
        TableNextRow(headers ? ImGuiTableRowFlags.Headers : ImGuiTableRowFlags.None, 0.0f)
        var cell = doc.nodes[row].first_child
        var column = 0
        while (cell >= 0) {
            if (TableSetColumnIndex(column)) {
                render_inline(doc, cell, state, GetContentRegionAvail().x,
                              style, 1.0f, 0, result)
            }
            column++
            cell = doc.nodes[cell].next_sibling
        }
        row = doc.nodes[row].next_sibling
    }
}

def private render_table(doc : MdDocument const; node_index : int;
                         var state : MarkdownViewState;
                         var style : MarkdownViewStyle;
                         var result : MarkdownViewResult) {
    let node = doc.nodes[node_index]
    if (node.column_count <= 0) return
    PushID(node_index)
    if (BeginTable("##markdown_table", node.column_count,
                   ImGuiTableFlags.Borders, float2(0.0f, 0.0f), 0.0f)) {
        for (column in range(node.column_count)) {
            TableSetupColumn("##column", ImGuiTableColumnFlags.None,
                             0.0f, uint(column))
        }
        var section = node.first_child
        while (section >= 0) {
            let is_head = doc.nodes[section].kind == MdNodeKind.table_head
            render_table_section(doc, section, is_head, state, style, result)
            section = doc.nodes[section].next_sibling
        }
        EndTable()
    }
    PopID()
    block_spacing(style, style.block_spacing)
}

def private render_code_block(doc : MdDocument const; node_index : int;
                              var state : MarkdownViewState;
                              var style : MarkdownViewStyle;
                              var result : MarkdownViewResult) {
    ensure_inline(doc, node_index, state)
    let content & = unsafe(state.nodes[node_index].content)
    let zoom = view_zoom(style)
    let font_size = (style.fonts.size_px > 0.0f
        ? style.fonts.size_px : GetFontSize()) * zoom
    let padding = style.code_padding * zoom
    var mono = style.fonts.monospace != null ? style.fonts.monospace : GetFont()
    let measured = CalcTextSizeForFont(mono, font_size, content.text)
    let child_border = GetStyle().ChildBorderSize
    let inner_width = max(1.0f, GetContentRegionAvail().x
        - padding * 2.0f - child_border * 2.0f)
    let needs_horizontal_scroll = measured.x > inner_width
    let scrollbar_height = needs_horizontal_scroll ? GetStyle().ScrollbarSize : 0.0f
    let height = max(font_size * 2.0f,
        measured.y + padding * 2.0f + child_border * 2.0f
        + GetStyle().ItemSpacing.y + scrollbar_height + 2.0f * zoom)
    PushStyleColor(ImGuiCol.ChildBg, style.code_background)
    PushID(node_index)
    let open = BeginChild("##markdown_code",
        float2(0.0f, height), ImGuiChildFlags.Borders,
        ImGuiWindowFlags.HorizontalScrollbar)
    if (open) {
        SetCursorPos(GetCursorPos() + float2(padding, padding))
        var code_style := style
        code_style.text_color = style.code_color
        code_style.show_link_copy = false
        let content_width = max(measured.x, GetContentRegionAvail().x - padding)
        render_inline(doc, node_index, state, max(content_width, 1.0f),
                      code_style, 1.0f, STYLE_CODE, result)
    }
    EndChild()
    PopID()
    PopStyleColor(1)
    block_spacing(style, style.block_spacing)
}

def private render_block(doc : MdDocument const; node_index : int;
                         var state : MarkdownViewState;
                         var style : MarkdownViewStyle;
                         var result : MarkdownViewResult) {
    if (node_index < 0 || node_index >= length(doc.nodes)) return
    let node = doc.nodes[node_index]
    if (node.kind == MdNodeKind.document) {
        render_children(doc, node_index, state, style, result)
    } elif (node.kind == MdNodeKind.paragraph) {
        render_inline(doc, node_index, state, GetContentRegionAvail().x,
                      style, 1.0f, 0, result)
        block_spacing(style, style.paragraph_spacing)
    } elif (node.kind == MdNodeKind.heading) {
        let scale = node.level == 1 ? 1.55f : (node.level == 2 ? 1.35f
                  : (node.level == 3 ? 1.18f : 1.05f))
        var heading_style := style
        heading_style.text_color = style.heading_color
        render_inline(doc, node_index, state, GetContentRegionAvail().x,
                      heading_style, scale, STYLE_HEADING, result)
        block_spacing(style, style.block_spacing)
    } elif (node.kind == MdNodeKind.unordered_list
            || node.kind == MdNodeKind.ordered_list) {
        render_list(doc, node_index, state, style, result)
    } elif (node.kind == MdNodeKind.quote) {
        let p0 = GetCursorScreenPos()
        let indent = zoomed(style, style.quote_indent)
        Indent(indent)
        render_children(doc, node_index, state, style, result)
        Unindent(indent)
        let p1 = GetCursorScreenPos()
        var dl = GetWindowDrawList()
        let bar_x = zoomed(style, 3.0f)
        *dl |> AddLine(p0 + float2(bar_x, 0.0f),
                       float2(p0.x + bar_x, p1.y),
                       GetColorU32(style.quote_color), zoomed(style, 2.0f))
    } elif (node.kind == MdNodeKind.thematic_break) {
        Separator()
        block_spacing(style, style.block_spacing)
    } elif (node.kind == MdNodeKind.code_block) {
        render_code_block(doc, node_index, state, style, result)
    } elif (node.kind == MdNodeKind.table_) {
        render_table(doc, node_index, state, style, result)
    } elif (node.kind == MdNodeKind.raw_html) {
        ensure_inline(doc, node_index, state)
        let content & = unsafe(state.nodes[node_index].content)
        TextColored(style.marker_color, content.text)
        block_spacing(style, style.block_spacing)
    } else {
        render_children(doc, node_index, state, style, result)
    }
}

def private finish_selection(doc : MdDocument const;
                             var state : MarkdownViewState;
                             var result : MarkdownViewResult) {
    let source = selected_source(state)
    if (source.start_byte < 0 || source.end_byte <= source.start_byte) return
    var accumulator = MdSelectionStyleAccumulator()
    for (i in range(length(state.nodes))) {
        if (state.nodes[i].content_valid) {
            let content & = unsafe(state.nodes[i].content)
            md_selection_include(accumulator, content, source)
        }
    }
    result.selection = MarkdownSelection(
        active = true,
        source = source,
        styles = md_selection_styles(accumulator),
        screen_valid = state.selection_screen_valid,
        screen_bounds = state.selection_screen_bounds,
        screen_anchor = state.selection_screen_anchor)
}

def public markdown_selection_text(state : MarkdownViewState const) : string {
    //! Flatten the selected display text on demand. This intentionally differs
    //! from `md_source_text`: Markdown delimiters are omitted and transformed
    //! entities retain the glyphs shown by the viewer. Separate inline blocks
    //! are joined with a newline.
    let source = selected_source(state)
    if (source.start_byte < 0 || source.end_byte <= source.start_byte) return ""
    var value = ""
    for (i in range(length(state.nodes))) {
        if (!state.nodes[i].content_valid) continue
        let content & = unsafe(state.nodes[i].content)
        var block_text = ""
        for (run in content.runs) {
            let display = selected_display(run, source)
            if (display.start_byte >= 0 && display.end_byte > display.start_byte) {
                block_text = block_text + slice(content.text, display.start_byte, display.end_byte)
            }
        }
        if (!empty(block_text)) {
            if (!empty(value)) {
                value = value + "\n"
            }
            value = value + block_text
        }
    }
    return value
}

def public markdown_view(id : string; doc : MdDocument const;
                         var state : MarkdownViewState;
                         var style : MarkdownViewStyle;
                         document_revision : int = 0) : MarkdownViewResult {
    var result = MarkdownViewResult()
    if (!doc.ok || doc.root < 0) {
        TextColored(float4(1.0f, 0.35f, 0.35f, 1.0f),
                    empty(doc.error) ? "Invalid Markdown document" : doc.error)
        return <- result
    }
    prepare_view_state(doc, state, document_revision)
    state.render_revision++
    // Stable visible bounds of the scrolling window. Cursor screen Y moves
    // with ScrollY and therefore cannot serve as the viewport edge.
    state.viewport_top = GetWindowPos().y + GetFrameHeight()
    state.viewport_bottom = (GetWindowPos().y + GetWindowSize().y
        - GetStyle().WindowPadding.y)
    let old_hovered_inline_node = state.hovered_inline_node
    let old_hovered_fragment = state.hovered_fragment
    let old_hovered_display_byte = state.hovered_display_byte
    state.hovered_inline_node = -1
    state.hovered_fragment = -1
    state.hovered_display_byte = -1
    state.caret_screen_valid = false
    state.caret_screen_height = 0.0f
    state.selection_changed = false
    state.selection_click_claimed = false
    state.selection_screen_valid = false
    if (IsMouseClicked(ImGuiMouseButton.Left, false)) {
        state.selection_pressed_semantic = -1
    }
    if (state.selection_dragging
            && IsMouseDragging(ImGuiMouseButton.Left, 2.0f)) {
        state.selection_dragged = true
    }
    navigate_selection_keyboard(state, style)
    var pushed_font = false
    if (style.fonts.regular != null) {
        let size = (style.fonts.size_px > 0.0f
            ? style.fonts.size_px : GetFontSize()) * view_zoom(style)
        PushFont(style.fonts.regular, size)
        pushed_font = true
    }
    PushID(id)
    render_block(doc, doc.root, state, style, result)
    PopID()
    ensure_keyboard_caret_visible(state)
    if (IsMouseClicked(ImGuiMouseButton.Left, false)
            && !state.selection_click_claimed) {
        let old_selection = selected_source(state)
        let had_selection = old_selection.end_byte > old_selection.start_byte
        markdown_view_clear_selection(state)
        state.selection_changed = had_selection
    }
    if (IsMouseReleased(ImGuiMouseButton.Left)) {
        if (state.selection_dragging) {
            state.selection_commit_revision++
        }
        state.selection_dragging = false
    }
    finish_selection(doc, state, result)
    result.selection_changed = state.selection_changed
    let io & = unsafe(GetIO())
    let copy_modifier = io.ConfigMacOSXBehaviors ? io.KeySuper : io.KeyCtrl
    if (result.selection.active && copy_modifier && IsKeyPressed(ImGuiKey.C, false)
            && IsWindowFocused(ImGuiFocusedFlags.RootAndChildWindows)
            && !IsAnyItemActive()) {
        let copy_status = clipboard_set_text(markdown_selection_text(state))
        result.selection_copied = copy_status == ClipboardStatus.ok
        if (result.selection_copied) {
            state.selection_copy_revision++
        }
    }
    if (old_hovered_inline_node != state.hovered_inline_node
            || old_hovered_fragment != state.hovered_fragment
            || old_hovered_display_byte != state.hovered_display_byte) {
        state.hover_revision++
    }
    if (pushed_font) {
        PopFont()
    }
    return <- result
}

def public markdown_view(id : string; doc : MdDocument const;
                         var style : MarkdownViewStyle) : MarkdownViewResult {
    //! Compatibility form. For live applications prefer the overload taking
    //! caller-owned `MarkdownViewState`, so stable frames reuse all layout.
    var state = MarkdownViewState()
    var result <- markdown_view(id, doc, state, style, 0)
    markdown_view_dispose(state)
    return <- result
}

def public markdown_view(id : string; doc : MdDocument const) : MarkdownViewResult {
    var style = MarkdownViewStyle()
    return <- markdown_view(id, doc, style)
}
