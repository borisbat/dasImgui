options gen2
options indenting = 4
options no_unused_function_arguments = false

module imgui_markdown_view shared

require imgui public
require imgui/imgui_markdown_model public
require imgui/imgui_text_flow
require imgui/imgui_icons
require math
require strings

//! Immediate-mode rendering counterpart to `imgui_markdown_model`.
//!
//! The document and inline-run model remain UI-independent. This layer owns
//! wrapping, colors, hover/click/copy behavior, and block chrome. Link actions
//! are returned to the host; the viewer never opens a URI on its own.

struct public MarkdownViewStyle {
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

let private STYLE_STRONG = 1
let private STYLE_EMPHASIS = 2
let private STYLE_CODE = 4
let private STYLE_STRIKE = 8
let private STYLE_LINK = 16

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

def private render_inline(id : string; doc : MdDocument const;
                          content : MdInlineContent const; max_width : float;
                          style : MarkdownViewStyle const;
                          var result : MarkdownViewResult) {
    let available = max(max_width, 1.0f)
    let icon_full = float2(
        style.copy_icon_size + GetStyle().FramePadding.x * 2.0f,
        style.copy_icon_size + GetStyle().FramePadding.y * 2.0f)
    var spans : array<TextFlowSpan>
    for (i in range(length(content.runs))) {
        let run = content.runs[i]
        let semantic_id = run_semantic_id(doc, run, i)
        let has_semantic = semantic_id >= 0
        let is_last_semantic = has_semantic && (i + 1 >= length(content.runs)
            || run_semantic_id(doc, content.runs[i + 1], i + 1) != semantic_id)
        spans |> push(TextFlowSpan(
            source = run.display,
            style_id = run_style(run),
            semantic_id = semantic_id,
            uri_wrap = run.is_link,
            trailing_control_id = style.show_link_copy && is_last_semantic
                ? semantic_id : -1,
            trailing_control_size = style.show_link_copy && is_last_semantic
                ? icon_full : float2(0.0f, 0.0f)))
    }
    let layout <- layout_text_flow(content.text, spans, available,
        GetTextLineHeight()) $(s : string) : float {
            return CalcTextSize(s).x
        }

    let origin = GetCursorScreenPos()
    Dummy(float2(available, max(layout.size.y, GetTextLineHeight())))
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
            *dl |> AddRectFilled(p0 - float2(2.0f, 0.0f),
                                 p1 + float2(2.0f, 0.0f),
                                 GetColorU32(style.code_background), 2.0f,
                                 ImDrawFlags.None)
        }
        let value = slice(content.text, fragment.source.start_byte,
                          fragment.source.end_byte)
        *dl |> AddText(p0, GetColorU32(color), value)
        if (hot_link) {
            let y = p0.y + GetTextLineHeight() - 1.0f
            *dl |> AddLine(float2(p0.x, y), float2(p1.x, y),
                           GetColorU32(color), 1.0f)
        }
        if (has_style(fragment.style_id, STYLE_STRIKE)) {
            let y = p0.y + GetTextLineHeight() * 0.52f
            *dl |> AddLine(float2(p0.x, y), float2(p1.x, y),
                           GetColorU32(color), 1.0f)
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
            if (icon_button_draw("##markdown_copy_{id}_{hovered}", "duplicate",
                                 style.copy_icon_size, 1.0f)) {
                let run_index = link_run_index(doc, content, hovered)
                let target = link_target(doc, content, hovered)
                SetClipboardText(target)
                result.copied = true
                result.copied_node = (run_index >= 0
                    ? content.runs[run_index].semantic_node : -1)
                if (run_index >= 0) {
                    result.source = content.runs[run_index].source
                }
                result.target := target
            }
            if (IsItemHovered()) SetTooltip("Copy URI")
        }
    }
    if (cursor_moved) {
        SetCursorScreenPos(cursor_after)
        Dummy(float2(0.0f, 0.0f))
    }
}

def private block_spacing(amount : float) {
    if (amount > 0.0f) Dummy(float2(0.0f, amount))
}

def private render_children(id : string; doc : MdDocument const; node_index : int;
                            style : MarkdownViewStyle const;
                            var result : MarkdownViewResult) {
    var child = doc.nodes[node_index].first_child
    while (child >= 0) {
        render_block(id, doc, child, style, result)
        child = doc.nodes[child].next_sibling
    }
}

def private render_list(id : string; doc : MdDocument const; node_index : int;
                        style : MarkdownViewStyle const;
                        var result : MarkdownViewResult) {
    let list = doc.nodes[node_index]
    var item = list.first_child
    var ordinal = list.start_number > 0 ? list.start_number : 1
    while (item >= 0) {
        let node = doc.nodes[item]
        var marker = list.kind == MdNodeKind.ordered_list ? "{ordinal}." : "•"
        if (node.is_task) {
            marker = node.is_checked ? "☑" : "☐"
        }
        TextColored(style.marker_color, marker)
        SameLine(0.0f, GetStyle().ItemInnerSpacing.x)
        var child = node.first_child
        while (child >= 0) {
            render_block(id, doc, child, style, result)
            child = doc.nodes[child].next_sibling
        }
        item = node.next_sibling
        ordinal++
    }
    block_spacing(list.is_tight ? 2.0f : style.block_spacing)
}

def private render_table_section(id : string; doc : MdDocument const;
                                 section_index : int; headers : bool;
                                 style : MarkdownViewStyle const;
                                 var result : MarkdownViewResult) {
    var row = doc.nodes[section_index].first_child
    while (row >= 0) {
        TableNextRow(headers ? ImGuiTableRowFlags.Headers : ImGuiTableRowFlags.None, 0.0f)
        var cell = doc.nodes[row].first_child
        var column = 0
        while (cell >= 0) {
            if (TableSetColumnIndex(column)) {
                let content <- md_inline_content(doc, cell)
                render_inline("{id}_cell_{cell}", doc, content,
                              GetContentRegionAvail().x, style, result)
            }
            column++
            cell = doc.nodes[cell].next_sibling
        }
        row = doc.nodes[row].next_sibling
    }
}

def private render_table(id : string; doc : MdDocument const; node_index : int;
                         style : MarkdownViewStyle const;
                         var result : MarkdownViewResult) {
    let node = doc.nodes[node_index]
    if (node.column_count <= 0) return
    if (BeginTable("##markdown_table_{id}_{node_index}", node.column_count,
                   ImGuiTableFlags.Borders, float2(0.0f, 0.0f), 0.0f)) {
        for (column in range(node.column_count)) {
            TableSetupColumn("##column_{column}", ImGuiTableColumnFlags.None,
                             0.0f, uint(column))
        }
        var section = node.first_child
        while (section >= 0) {
            let is_head = doc.nodes[section].kind == MdNodeKind.table_head
            render_table_section(id, doc, section, is_head, style, result)
            section = doc.nodes[section].next_sibling
        }
        EndTable()
    }
    block_spacing(style.block_spacing)
}

def private render_code_block(id : string; doc : MdDocument const; node_index : int;
                              style : MarkdownViewStyle const) {
    let content <- md_inline_content(doc, node_index)
    let measured = CalcTextSize(content.text)
    let height = max(GetTextLineHeight() * 2.0f,
                     measured.y + style.code_padding * 2.0f)
    PushStyleColor(ImGuiCol.ChildBg, style.code_background)
    let open = BeginChild("##markdown_code_{id}_{node_index}",
        float2(0.0f, height), ImGuiChildFlags.Borders,
        ImGuiWindowFlags.HorizontalScrollbar)
    if (open) {
        SetCursorPos(GetCursorPos() + float2(style.code_padding, style.code_padding))
        TextColored(style.code_color, content.text)
    }
    EndChild()
    PopStyleColor(1)
    block_spacing(style.block_spacing)
}

def private render_block(id : string; doc : MdDocument const; node_index : int;
                         style : MarkdownViewStyle const;
                         var result : MarkdownViewResult) {
    if (node_index < 0 || node_index >= length(doc.nodes)) return
    let node = doc.nodes[node_index]
    if (node.kind == MdNodeKind.document) {
        render_children(id, doc, node_index, style, result)
    } elif (node.kind == MdNodeKind.paragraph) {
        let content <- md_inline_content(doc, node_index)
        render_inline("{id}_p_{node_index}", doc, content,
                      GetContentRegionAvail().x, style, result)
        block_spacing(style.paragraph_spacing)
    } elif (node.kind == MdNodeKind.heading) {
        let content <- md_inline_content(doc, node_index)
        let scale = node.level == 1 ? 1.55f : (node.level == 2 ? 1.35f
                  : (node.level == 3 ? 1.18f : 1.05f))
        PushFont(GetFont(), GetFontSize() * scale)
        var heading_style = style
        heading_style.text_color = style.heading_color
        render_inline("{id}_h_{node_index}", doc, content,
                      GetContentRegionAvail().x, heading_style, result)
        PopFont()
        block_spacing(style.block_spacing)
    } elif (node.kind == MdNodeKind.unordered_list
            || node.kind == MdNodeKind.ordered_list) {
        render_list(id, doc, node_index, style, result)
    } elif (node.kind == MdNodeKind.quote) {
        let p0 = GetCursorScreenPos()
        Indent(style.quote_indent)
        render_children(id, doc, node_index, style, result)
        Unindent(style.quote_indent)
        let p1 = GetCursorScreenPos()
        var dl = GetWindowDrawList()
        *dl |> AddLine(p0 + float2(3.0f, 0.0f),
                       float2(p0.x + 3.0f, p1.y),
                       GetColorU32(style.quote_color), 2.0f)
    } elif (node.kind == MdNodeKind.thematic_break) {
        Separator()
        block_spacing(style.block_spacing)
    } elif (node.kind == MdNodeKind.code_block) {
        render_code_block(id, doc, node_index, style)
    } elif (node.kind == MdNodeKind.table_) {
        render_table(id, doc, node_index, style, result)
    } elif (node.kind == MdNodeKind.raw_html) {
        let content <- md_inline_content(doc, node_index)
        TextColored(style.marker_color, content.text)
        block_spacing(style.block_spacing)
    } else {
        render_children(id, doc, node_index, style, result)
    }
}

def public markdown_view(id : string; doc : MdDocument const;
                         style : MarkdownViewStyle = MarkdownViewStyle()) : MarkdownViewResult {
    var result = MarkdownViewResult()
    if (!doc.ok || doc.root < 0) {
        TextColored(float4(1.0f, 0.35f, 0.35f, 1.0f),
                    empty(doc.error) ? "Invalid Markdown document" : doc.error)
        return <- result
    }
    PushID(id)
    render_block(id, doc, doc.root, style, result)
    PopID()
    return <- result
}
