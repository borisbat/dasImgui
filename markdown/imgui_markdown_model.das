options gen2
options indenting = 4

module imgui_markdown_model shared

require imgui
require imgui/imgui_text_flow public
require daslib/utf8_utils
require math
require strings

//! View-independent Markdown document model.
//!
//! MD4C owns CommonMark/GFM recognition and emits SAX-style events through a
//! deliberately small native bridge. This module turns those events into a
//! flat, index-addressed tree suitable for viewers, editors, search, and tests.
//! Exact ranges identify bytes in `MdDocument.source`; container ranges are
//! conservative unions of their descendants and therefore marked non-exact.

enum public MdNodeKind {
    document
    quote
    unordered_list
    ordered_list
    list_item
    thematic_break
    heading
    code_block
    raw_html
    paragraph
    table_
    table_head
    table_body
    table_row
    table_header_cell
    table_cell
    emphasis
    strong
    link
    image
    inline_code
    strikethrough
    latex_math
    latex_math_display
    wiki_link
    underline
    text
    null_character
    hard_break
    soft_break
    entity
    code_text
    html_text
    latex_text
    unknown
}

enum public MdAlignment {
    default_
    left
    center
    right
}

struct public MdParseOptions {
    tables : bool = true
    task_lists : bool = true
    strikethrough : bool = true
    permissive_autolinks : bool = true
    raw_html : bool = false
}

struct public MdNode {
    kind : MdNodeKind = MdNodeKind.unknown

    //! Stable indices into `MdDocument.nodes`; -1 means absent.
    parent : int = -1
    first_child : int = -1
    last_child : int = -1
    next_sibling : int = -1

    //! Exact for source-backed leaves. Containers expose a derived content
    //! union so clients can still navigate approximately without being lied to
    //! about Markdown delimiters that MD4C intentionally does not report.
    source : TextSourceRange = TextSourceRange(start_byte = -1, end_byte = -1)
    source_exact : bool = false

    level : int = 0
    marker : int = 0
    start_number : int = 0
    alignment : MdAlignment = MdAlignment.default_
    column_count : int = 0
    head_row_count : int = 0
    body_row_count : int = 0

    is_tight : bool = false
    is_task : bool = false
    is_checked : bool = false
    is_autolink : bool = false

    //! Text leaves normally refer back to `source` without duplicating bytes.
    //! `literal` is used only when MD4C emits transformed/non-source text.
    literal : string
    destination : string
    title : string
    info : string
    language : string
}

struct public MdDocument {
    source : string
    nodes : array<MdNode>
    root : int = -1
    ok : bool = false
    error : string
}

struct public MdInlineRun {
    //! Byte range in `MdInlineContent.text` and its corresponding Markdown
    //! source range. Display bytes can differ for entities and soft breaks.
    display : TextSourceRange
    source : TextSourceRange
    source_exact : bool = false
    node_index : int = -1
    semantic_node : int = -1
    is_strong : bool = false
    is_emphasis : bool = false
    is_code : bool = false
    is_strikethrough : bool = false
    is_link : bool = false
}

struct public MdInlineContent {
    text : string
    runs : array<MdInlineRun>
}

def private block_kind(kind : int) : MdNodeKind {
    if (kind == 0) return MdNodeKind.document
    if (kind == 1) return MdNodeKind.quote
    if (kind == 2) return MdNodeKind.unordered_list
    if (kind == 3) return MdNodeKind.ordered_list
    if (kind == 4) return MdNodeKind.list_item
    if (kind == 5) return MdNodeKind.thematic_break
    if (kind == 6) return MdNodeKind.heading
    if (kind == 7) return MdNodeKind.code_block
    if (kind == 8) return MdNodeKind.raw_html
    if (kind == 9) return MdNodeKind.paragraph
    if (kind == 10) return MdNodeKind.table_
    if (kind == 11) return MdNodeKind.table_head
    if (kind == 12) return MdNodeKind.table_body
    if (kind == 13) return MdNodeKind.table_row
    if (kind == 14) return MdNodeKind.table_header_cell
    if (kind == 15) return MdNodeKind.table_cell
    return MdNodeKind.unknown
}

def private span_kind(kind : int) : MdNodeKind {
    if (kind == 0) return MdNodeKind.emphasis
    if (kind == 1) return MdNodeKind.strong
    if (kind == 2) return MdNodeKind.link
    if (kind == 3) return MdNodeKind.image
    if (kind == 4) return MdNodeKind.inline_code
    if (kind == 5) return MdNodeKind.strikethrough
    if (kind == 6) return MdNodeKind.latex_math
    if (kind == 7) return MdNodeKind.latex_math_display
    if (kind == 8) return MdNodeKind.wiki_link
    if (kind == 9) return MdNodeKind.underline
    return MdNodeKind.unknown
}

def private text_kind(kind : int) : MdNodeKind {
    if (kind == 0) return MdNodeKind.text
    if (kind == 1) return MdNodeKind.null_character
    if (kind == 2) return MdNodeKind.hard_break
    if (kind == 3) return MdNodeKind.soft_break
    if (kind == 4) return MdNodeKind.entity
    if (kind == 5) return MdNodeKind.code_text
    if (kind == 6) return MdNodeKind.html_text
    if (kind == 7) return MdNodeKind.latex_text
    return MdNodeKind.unknown
}

def private md_alignment(value : int) : MdAlignment {
    if (value == 1) return MdAlignment.left
    if (value == 2) return MdAlignment.center
    if (value == 3) return MdAlignment.right
    return MdAlignment.default_
}

def private parser_flags(parse_options : MdParseOptions const) : int {
    var flags = 0u
    if (parse_options.permissive_autolinks) {
        flags |= 0x0004u // MD_FLAG_PERMISSIVEURLAUTOLINKS
        flags |= 0x0008u // MD_FLAG_PERMISSIVEEMAILAUTOLINKS
        flags |= 0x0400u // MD_FLAG_PERMISSIVEWWWAUTOLINKS
    }
    if (!parse_options.raw_html) {
        flags |= 0x0020u // MD_FLAG_NOHTMLBLOCKS
        flags |= 0x0040u // MD_FLAG_NOHTMLSPANS
    }
    if (parse_options.tables) {
        flags |= 0x0100u
    }
    if (parse_options.strikethrough) {
        flags |= 0x0200u
    }
    if (parse_options.task_lists) {
        flags |= 0x0800u
    }
    return int(flags)
}

def private attach_node(var doc : MdDocument; var stack : array<int>;
                        var node : MdNode) : int {
    let index = length(doc.nodes)
    if (!empty(stack)) {
        let parent = stack[length(stack) - 1]
        node.parent = parent
        if (doc.nodes[parent].first_child < 0) {
            doc.nodes[parent].first_child = index
        } else {
            doc.nodes[doc.nodes[parent].last_child].next_sibling = index
        }
        doc.nodes[parent].last_child = index
    }
    doc.nodes |> push(<- node)
    return index
}

def private apply_block_detail(var node : MdNode; kind, flags, offset, size,
                               aux0, aux1 : int; text, text2 : string) {
    if (kind == 2) {
        node.is_tight = flags != 0
        node.marker = aux0
    } elif (kind == 3) {
        node.is_tight = flags != 0
        node.start_number = aux0
        node.marker = aux1
    } elif (kind == 4) {
        node.is_task = flags != 0
        node.is_checked = node.is_task && aux0 != int(' ')
        node.marker = aux0
        if (node.is_task && offset >= 0) {
            node.source = TextSourceRange(start_byte = offset, end_byte = offset + 1)
        }
    } elif (kind == 6) {
        node.level = aux0
    } elif (kind == 7) {
        node.marker = aux0
        node.info := text
        node.language := text2
    } elif (kind == 10) {
        node.column_count = aux0
        node.head_row_count = aux1
        node.body_row_count = size
    } elif (kind == 14 || kind == 15) {
        node.alignment = md_alignment(aux0)
    }
}

def private apply_span_detail(var node : MdNode; kind, flags : int;
                              text, text2 : string) {
    if (kind == 2 || kind == 3) {
        node.destination := text
        node.title := text2
        node.is_autolink = kind == 2 && flags != 0
    } elif (kind == 8) {
        node.destination := text
    }
}

def private include_range(var node : MdNode; source_range : TextSourceRange const) {
    if (source_range.start_byte < 0 || source_range.end_byte < source_range.start_byte) return
    if (node.source.start_byte < 0) {
        node.source = source_range
    } else {
        node.source.start_byte = min(node.source.start_byte, source_range.start_byte)
        node.source.end_byte = max(node.source.end_byte, source_range.end_byte)
    }
}

def private close_node(var doc : MdDocument; var stack : array<int>) {
    if (empty(stack)) return
    let index = stack[length(stack) - 1]
    stack |> pop()
    var child = doc.nodes[index].first_child
    while (child >= 0) {
        include_range(doc.nodes[index], doc.nodes[child].source)
        child = doc.nodes[child].next_sibling
    }
}

def public md_node_text(doc : MdDocument const; node_index : int) : string {
    //! Return the exact Markdown source bytes represented by a leaf.
    if (node_index < 0 || node_index >= length(doc.nodes)) return ""
    let node = doc.nodes[node_index]
    if (node.source_exact && node.source.start_byte >= 0
            && node.source.end_byte <= length(doc.source)) {
        return slice(doc.source, node.source.start_byte, node.source.end_byte)
    }
    return node.literal
}

def public md_node_display_text(doc : MdDocument const; node_index : int) : string {
    //! Return display-ready text. Entities and null characters retain their
    //! exact source range while exposing MD4C's decoded/replacement text here.
    if (node_index < 0 || node_index >= length(doc.nodes)) return ""
    let node = doc.nodes[node_index]
    if (!empty(node.literal)) return node.literal
    return md_node_text(doc, node_index)
}

def private collect_inline(doc : MdDocument const; node_index : int;
                           var content : MdInlineContent;
                           strong, emphasis, code, strike : bool;
                           semantic_node : int) {
    if (node_index < 0 || node_index >= length(doc.nodes)) return
    let node = doc.nodes[node_index]
    let next_strong = strong || node.kind == MdNodeKind.strong
    let next_emphasis = emphasis || node.kind == MdNodeKind.emphasis
    let next_code = code || node.kind == MdNodeKind.inline_code
    let next_strike = strike || node.kind == MdNodeKind.strikethrough
    var next_semantic = semantic_node
    if (node.kind == MdNodeKind.link || node.kind == MdNodeKind.image) {
        next_semantic = node_index
    }

    let is_leaf = (node.kind == MdNodeKind.text
        || node.kind == MdNodeKind.null_character
        || node.kind == MdNodeKind.hard_break
        || node.kind == MdNodeKind.soft_break
        || node.kind == MdNodeKind.entity
        || node.kind == MdNodeKind.code_text
        || node.kind == MdNodeKind.html_text
        || node.kind == MdNodeKind.latex_text)
    if (is_leaf) {
        var value = md_node_display_text(doc, node_index)
        if (node.kind == MdNodeKind.soft_break) {
            value = " "
        } elif (node.kind == MdNodeKind.hard_break) {
            value = "\n"
        }
        let start = length(content.text)
        content.text = content.text + value
        content.runs |> push(MdInlineRun(
            display = TextSourceRange(start_byte = start, end_byte = start + length(value)),
            source = node.source,
            source_exact = node.source_exact,
            node_index = node_index,
            semantic_node = next_semantic,
            is_strong = next_strong,
            is_emphasis = next_emphasis,
            is_code = next_code,
            is_strikethrough = next_strike,
            is_link = next_semantic >= 0))
        return
    }

    var child = node.first_child
    while (child >= 0) {
        collect_inline(doc, child, content, next_strong, next_emphasis,
                       next_code, next_strike, next_semantic)
        child = doc.nodes[child].next_sibling
    }
}

def public md_inline_content(doc : MdDocument const; node_index : int) : MdInlineContent {
    //! Flatten one inline-bearing subtree into display text plus semantic/style
    //! runs. This remains independent of ImGui and is shared by future viewer,
    //! editor, accessibility, and copy/export paths.
    var content = MdInlineContent()
    collect_inline(doc, node_index, content, false, false, false, false, -1)
    return <- content
}

def public md_parse(source : string;
                    parse_options : MdParseOptions = MdParseOptions()) : MdDocument {
    var doc = MdDocument()
    doc.source := source
    if (!is_utf8_string_valid(source)) {
        doc.error = "Markdown source is not valid UTF-8"
        return <- doc
    }

    var stack : array<int>
    var callback_error = false
    var status : int = _markdown_parse_events(doc.source, length(doc.source),
        parser_flags(parse_options)) $(var event, kind, flags, offset, size,
                                aux0, aux1 : int; text, text2 : string) {
            if (event == 0) { // enter block
                var node = MdNode(kind = block_kind(kind))
                apply_block_detail(node, kind, flags, offset, size,
                                   aux0, aux1, text, text2)
                let index = attach_node(doc, stack, node)
                if (kind == 0) {
                    doc.root = index
                }
                stack |> push(index)
            } elif (event == 1) { // leave block
                close_node(doc, stack)
            } elif (event == 2) { // enter span
                var node = MdNode(kind = span_kind(kind))
                apply_span_detail(node, kind, flags, text, text2)
                let index = attach_node(doc, stack, node)
                stack |> push(index)
            } elif (event == 3) { // leave span
                close_node(doc, stack)
            } elif (event == 4) { // text
                var node = MdNode(kind = text_kind(kind))
                if (offset >= 0 && size >= 0 && offset + size <= length(doc.source)) {
                    node.source = TextSourceRange(
                        start_byte = offset, end_byte = offset + size)
                    node.source_exact = true
                } else {
                    node.literal := text
                }
                if (node.kind == MdNodeKind.entity || node.kind == MdNodeKind.null_character) {
                    node.literal := text
                }
                attach_node(doc, stack, node)
            } elif (event == 5) { // debug/error diagnostic
                callback_error = true
                doc.error := text
            }
        }

    if (status != 0) {
        if (empty(doc.error)) {
            doc.error = "MD4C parse failed with status {status}"
        }
        return <- doc
    }
    if (callback_error) return <- doc
    if (!empty(stack)) {
        doc.error = "Markdown parser returned an unbalanced event stream"
        return <- doc
    }
    if (doc.root < 0) {
        doc.error = "Markdown parser did not emit a document root"
        return <- doc
    }
    doc.ok = true
    return <- doc
}
