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

struct public MarkdownViewResult {
    hovered : bool = false
    activated : bool = false
    copied : bool = false
    hovered_node : int = -1
    activated_node : int = -1
    copied_node : int = -1
    source : TextSourceRange = TextSourceRange(start_byte = -1, end_byte = -1)
    target : string
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

def public markdown_view_invalidate(var state : MarkdownViewState) {
    //! Deterministically release all retained strings and arrays. The outer
    //! cache capacity is retained for a same-sized replacement document.
    for (i in range(length(state.nodes))) {
        var entry & = unsafe(state.nodes[i])
        clear_node_cache(entry)
    }
    state.document_revision = -1
    state.node_count = 0
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
    Dummy(float2(available, max(layout.size.y, line_height)))
    let cursor_after = GetCursorScreenPos()

    var hovered = -1
    for (fragment in layout.fragments) {
        if (fragment.semantic_id >= 0 && IsMouseHoveringRect(
                fragment_min(origin, fragment), fragment_max(origin, fragment), true)) {
            hovered = fragment.semantic_id
        }
    }
    var cursor_moved = false
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
        if (has_style(fragment.style_id, STYLE_CODE)) {
            *dl |> AddRectFilled(p0 - float2(2.0f * zoom, 0.0f),
                                 p1 + float2(2.0f * zoom, 0.0f),
                                 GetColorU32(style.code_background), 2.0f * zoom,
                                 ImDrawFlags.None)
        }
        var font = font_for_style(fragment.style_id, style.fonts, fallback_font)
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
        if (IsMouseClicked(ImGuiMouseButton.Left, false)) {
            let run_index = link_run_index(doc, content, hovered)
            result.activated = true
            result.activated_node = (run_index >= 0
                ? content.runs[run_index].semantic_node : -1)
            if (run_index >= 0) {
                result.source = content.runs[run_index].source
            }
            result.target := link_target(doc, content, hovered)
        }
        for (fragment in layout.fragments) {
            if (!fragment.is_control || fragment.control_id != hovered) continue
            SetCursorScreenPos(fragment_min(origin, fragment))
            cursor_moved = true
            if (icon_button_draw("##markdown_copy", "duplicate",
                                 style.copy_icon_size * zoom, 1.0f)) {
                let run_index = link_run_index(doc, content, hovered)
                let target = link_target(doc, content, hovered)
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
            if (IsItemHovered()) SetTooltip("Copy URI")
        }
    }
    if (cursor_moved) {
        SetCursorScreenPos(cursor_after)
        Dummy(float2(0.0f, 0.0f))
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
                              var style : MarkdownViewStyle) {
    ensure_inline(doc, node_index, state)
    let content & = unsafe(state.nodes[node_index].content)
    let zoom = view_zoom(style)
    let font_size = (style.fonts.size_px > 0.0f
        ? style.fonts.size_px : GetFontSize()) * zoom
    let padding = style.code_padding * zoom
    var mono = style.fonts.monospace != null ? style.fonts.monospace : GetFont()
    let measured = CalcTextSizeForFont(mono, font_size, content.text)
    let height = max(font_size * 2.0f,
                     measured.y + padding * 2.0f)
    PushStyleColor(ImGuiCol.ChildBg, style.code_background)
    PushID(node_index)
    let open = BeginChild("##markdown_code",
        float2(0.0f, height), ImGuiChildFlags.Borders,
        ImGuiWindowFlags.HorizontalScrollbar)
    if (open) {
        SetCursorPos(GetCursorPos() + float2(padding, padding))
        PushFont(mono, font_size)
        TextColored(style.code_color, content.text)
        PopFont()
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
        render_code_block(doc, node_index, state, style)
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
