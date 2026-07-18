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
    is_automatic_uri : bool = false
    //! Images are one atomic inline run. `display` and `image_alt` provide the
    //! plain-text fallback; `source` is the conservative alt subtree because
    //! MD4C does not expose the complete image-syntax span.
    is_image : bool = false
    image_alt : string
    destination : string
    title : string
}

struct public MdInlineContent {
    text : string
    runs : array<MdInlineRun>
}

bitfield public MdSelectionStyles {
    //! Semantic styles present in the selected display text. `all_regular`
    //! means every contributing run is unstyled; `has_mixed_styles` means at
    //! least two distinct combinations of the other style bits occur.
    all_regular
    has_strong
    has_emphasis
    has_code
    has_strikethrough
    has_links
    has_images
    has_mixed_styles
}

struct public MdTextPosition {
    //! One caret in flattened inline display text and its corresponding byte
    //! position in the original Markdown source.
    valid : bool = false
    inline_node : int = -1
    display_byte : int = -1
    source_byte : int = -1
    trailing : bool = false
}

struct public MdSelectionStyleAccumulator {
    //! View-independent accumulator: callers can include one or many inline
    //! contents, which is how a viewer aggregates a cross-block selection.
    styles : MdSelectionStyles
    first_mask : int = -1
    matched_runs : int = 0
    regular_only : bool = true
}

struct public MdSelectionExport {
    //! Platform-neutral representations of one source-mapped selection.
    //! All representations follow rendered inline runs (entities stay
    //! transformed). Markdown syntax is reconstructed around partial styled
    //! selections so copied bold/link text remains valid when pasted alone.
    plain_text : string
    markdown : string
    html : string
    uri_list : string
    block_count : int = 0
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
    let next_code = (code || node.kind == MdNodeKind.inline_code
        || node.kind == MdNodeKind.code_block)
    let next_strike = strike || node.kind == MdNodeKind.strikethrough

    if (node.kind == MdNodeKind.image) {
        // Keep replaced content atomic in the public model. The image's child
        // subtree is flattened only to obtain its accessible/plain-text alt.
        var alt_content = MdInlineContent()
        var child = node.first_child
        while (child >= 0) {
            collect_inline(doc, child, alt_content, false, false,
                           false, false, -1)
            child = doc.nodes[child].next_sibling
        }
        var alt := alt_content.text
        delete alt_content.runs
        let display_alt = empty(alt) ? "Image" : alt
        let start = length(content.text)
        content.text = content.text + display_alt
        content.runs |> push(MdInlineRun(
            display = TextSourceRange(
                start_byte = start, end_byte = start + length(display_alt)),
            source = node.source,
            source_exact = false,
            node_index = node_index,
            semantic_node = node_index,
            is_strong = next_strong,
            is_emphasis = next_emphasis,
            is_code = next_code,
            is_strikethrough = next_strike,
            is_link = true,
            is_image = true,
            image_alt = alt,
            destination = node.destination,
            title = node.title))
        return
    }

    var next_semantic = semantic_node
    if (node.kind == MdNodeKind.link) {
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
        var run = MdInlineRun(
            display = TextSourceRange(start_byte = start, end_byte = start + length(value)),
            source = node.source,
            source_exact = node.source_exact,
            node_index = node_index,
            semantic_node = next_semantic,
            is_strong = next_strong,
            is_emphasis = next_emphasis,
            is_code = next_code,
            is_strikethrough = next_strike,
            is_link = next_semantic >= 0)
        if (next_semantic >= 0) {
            run.destination := doc.nodes[next_semantic].destination
            run.title := doc.nodes[next_semantic].title
        }
        content.runs |> push(<- run)
        return
    }

    var child = node.first_child
    while (child >= 0) {
        collect_inline(doc, child, content, next_strong, next_emphasis,
                       next_code, next_strike, next_semantic)
        child = doc.nodes[child].next_sibling
    }
}

def private split_plain_uris(doc : MdDocument const; var content : MdInlineContent) {
    var split_runs : array<MdInlineRun>
    for (i in range(length(content.runs))) {
        var base <- content.runs[i]
        let can_detect = (!base.is_link && base.source_exact
            && base.node_index >= 0
            && doc.nodes[base.node_index].kind == MdNodeKind.text)
        if (!can_detect) {
            split_runs |> push(<- base)
            continue
        }
        let value = slice(content.text, base.display.start_byte, base.display.end_byte)
        let uris <- text_uris(value)
        if (empty(uris)) {
            split_runs |> push(<- base)
            continue
        }
        var cursor = 0
        for (uri in uris) {
            if (uri.source.start_byte > cursor) {
                var before := base
                before.display = TextSourceRange(
                    start_byte = base.display.start_byte + cursor,
                    end_byte = base.display.start_byte + uri.source.start_byte)
                before.source = TextSourceRange(
                    start_byte = base.source.start_byte + cursor,
                    end_byte = base.source.start_byte + uri.source.start_byte)
                split_runs |> push(<- before)
            }
            var linked := base
            linked.display = TextSourceRange(
                start_byte = base.display.start_byte + uri.source.start_byte,
                end_byte = base.display.start_byte + uri.source.end_byte)
            linked.source = TextSourceRange(
                start_byte = base.source.start_byte + uri.source.start_byte,
                end_byte = base.source.start_byte + uri.source.end_byte)
            linked.is_link = true
            linked.is_automatic_uri = true
            linked.semantic_node = -1
            let display_uri = slice(value, uri.source.start_byte, uri.source.end_byte)
            linked.destination := (uri.kind == TextUriKind.www
                ? "https://" + display_uri : display_uri)
            split_runs |> push(<- linked)
            cursor = uri.source.end_byte
        }
        if (cursor < length(value)) {
            var after := base
            after.display = TextSourceRange(
                start_byte = base.display.start_byte + cursor,
                end_byte = base.display.end_byte)
            after.source = TextSourceRange(
                start_byte = base.source.start_byte + cursor,
                end_byte = base.source.end_byte)
            split_runs |> push(<- after)
        }
    }
    content.runs <- split_runs
}

def public md_inline_content(doc : MdDocument const; node_index : int) : MdInlineContent {
    //! Flatten one inline-bearing subtree into display text plus semantic/style
    //! runs. This remains independent of ImGui and is shared by future viewer,
    //! editor, accessibility, and copy/export paths.
    var content = MdInlineContent()
    collect_inline(doc, node_index, content, false, false, false, false, -1)
    split_plain_uris(doc, content)
    return <- content
}

def public md_node_kind_is_inline(kind : MdNodeKind) : bool {
    //! True for span/text nodes that participate in one inline layout.
    return (kind == MdNodeKind.emphasis
        || kind == MdNodeKind.strong
        || kind == MdNodeKind.link
        || kind == MdNodeKind.image
        || kind == MdNodeKind.inline_code
        || kind == MdNodeKind.strikethrough
        || kind == MdNodeKind.latex_math
        || kind == MdNodeKind.latex_math_display
        || kind == MdNodeKind.wiki_link
        || kind == MdNodeKind.underline
        || kind == MdNodeKind.text
        || kind == MdNodeKind.null_character
        || kind == MdNodeKind.hard_break
        || kind == MdNodeKind.soft_break
        || kind == MdNodeKind.entity
        || kind == MdNodeKind.code_text
        || kind == MdNodeKind.html_text
        || kind == MdNodeKind.latex_text
        || kind == MdNodeKind.unknown)
}

def public md_inline_content_direct_children(
                                             doc : MdDocument const; node_index : int) : MdInlineContent {
    //! Flatten only direct inline children of a block container. MD4C emits
    //! tight-list inline nodes directly under list_item, without a paragraph.
    var content = MdInlineContent()
    if (node_index < 0 || node_index >= length(doc.nodes)) return <- content
    var child = doc.nodes[node_index].first_child
    while (child >= 0) {
        if (md_node_kind_is_inline(doc.nodes[child].kind)) {
            collect_inline(doc, child, content, false, false, false, false, -1)
        }
        child = doc.nodes[child].next_sibling
    }
    split_plain_uris(doc, content)
    return <- content
}

def private md_run_style_mask(run : MdInlineRun const) : int {
    var mask = 0
    if (run.is_strong) {
        mask = mask | 1
    }
    if (run.is_emphasis) {
        mask = mask | 2
    }
    if (run.is_code) {
        mask = mask | 4
    }
    if (run.is_strikethrough) {
        mask = mask | 8
    }
    if (run.is_link) {
        mask = mask | 16
    }
    if (run.is_image) {
        mask = mask | 32
    }
    return mask
}

def public md_inline_position(content : MdInlineContent const;
                              inline_node, display_byte : int;
                              trailing : bool = false) : MdTextPosition {
    //! Convert a grapheme-boundary display caret to original Markdown bytes.
    //! At a style boundary `trailing` selects the run on the left; otherwise
    //! the run on the right is preferred. Transformed runs (for example an
    //! entity displayed as one glyph) snap to the whole source token.
    if (empty(content.runs)) return MdTextPosition()
    let at = clamp(display_byte, 0, length(content.text))
    var chosen = -1
    if (trailing) {
        for (i in range(length(content.runs))) {
            let run = content.runs[i]
            if (run.display.start_byte < at && at <= run.display.end_byte) {
                chosen = i
                break
            }
        }
    } else {
        for (i in range(length(content.runs))) {
            let run = content.runs[i]
            if (run.display.start_byte <= at && at < run.display.end_byte) {
                chosen = i
                break
            }
        }
    }
    if (chosen < 0) {
        chosen = trailing ? length(content.runs) - 1 : 0
    }

    let run = content.runs[chosen]
    let display_size = run.display.end_byte - run.display.start_byte
    let source_size = run.source.end_byte - run.source.start_byte
    var source_byte = run.source.start_byte
    if (run.source_exact && display_size == source_size) {
        source_byte += clamp(at - run.display.start_byte, 0, display_size)
    } elif (at >= run.display.end_byte) {
        source_byte = run.source.end_byte
    } elif (at > run.display.start_byte && trailing) {
        source_byte = run.source.end_byte
    }
    return MdTextPosition(
        valid = source_byte >= 0,
        inline_node = inline_node,
        display_byte = at,
        source_byte = source_byte,
        trailing = trailing)
}

def public md_text_selection_range(anchor, focus : MdTextPosition const) : TextSourceRange {
    if (!anchor.valid || !focus.valid) {
        return TextSourceRange(start_byte = -1, end_byte = -1)
    }
    return TextSourceRange(
        start_byte = min(anchor.source_byte, focus.source_byte),
        end_byte = max(anchor.source_byte, focus.source_byte))
}

def public md_selection_include(var accumulator : MdSelectionStyleAccumulator;
                                content : MdInlineContent const;
                                source : TextSourceRange const) {
    //! Include semantic runs overlapping an original-source selection.
    if (source.start_byte < 0 || source.end_byte <= source.start_byte) return
    for (run in content.runs) {
        if (run.source.start_byte < 0 || run.source.end_byte <= source.start_byte
                || run.source.start_byte >= source.end_byte) continue
        let mask = md_run_style_mask(run)
        if (accumulator.first_mask < 0) {
            accumulator.first_mask = mask
        } elif (accumulator.first_mask != mask) {
            accumulator.styles.has_mixed_styles = true
        }
        accumulator.matched_runs++
        accumulator.regular_only = accumulator.regular_only && mask == 0
        accumulator.styles.has_strong = accumulator.styles.has_strong || run.is_strong
        accumulator.styles.has_emphasis = accumulator.styles.has_emphasis || run.is_emphasis
        accumulator.styles.has_code = accumulator.styles.has_code || run.is_code
        accumulator.styles.has_strikethrough = (accumulator.styles.has_strikethrough
            || run.is_strikethrough)
        accumulator.styles.has_links = accumulator.styles.has_links || run.is_link
        accumulator.styles.has_images = accumulator.styles.has_images || run.is_image
    }
}

def public md_selection_styles(accumulator : MdSelectionStyleAccumulator const) : MdSelectionStyles {
    var styles = accumulator.styles
    styles.all_regular = accumulator.matched_runs > 0 && accumulator.regular_only
    return styles
}

def public md_selected_display_range(run : MdInlineRun const;
                                     source : TextSourceRange const) : TextSourceRange {
    //! Map a source selection onto rendered bytes. Transformed entities and
    //! other inexact runs remain atomic because splitting them would invent a
    //! source position the parser never supplied.
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
    return run.display
}

def private md_html_text(value : string) : string {
    return value |> replace("&", "&amp;") |> replace("<", "&lt;") |> replace(">", "&gt;")
}

def private md_html_attribute(value : string) : string {
    return value |> md_html_text() |> replace("\"", "&quot;") |> replace("'", "&#39;")
}

def private md_markdown_text(value : string) : string {
    var result = value |> replace("\\", "\\\\")
    result = result |> replace("`", "\\`")
    result = result |> replace("*", "\\*")
    result = result |> replace("_", "\\_")
    result = result |> replace("[", "\\[")
    result = result |> replace("]", "\\]")
    result = result |> replace("~", "\\~")
    return result
}

def private md_markdown_destination(value : string) : string {
    return value |> replace("\\", "\\\\") |> replace(")", "\\)")
}

def private md_export_uri(var value : string&; uri : string) {
    if (empty(uri)) return
    let line = uri + "\r\n"
    if ((value |> find(line)) < 0) {
        value = value + line
    }
}

def public md_selection_export_include(var result : MdSelectionExport;
                                       content : MdInlineContent const;
                                       source : TextSourceRange const) {
    //! Add one inline block to a rich selection export. Call blocks in document
    //! order; only blocks overlapping `source` contribute separators.
    var block_plain = ""
    var block_markdown = ""
    var block_html = ""
    for (run in content.runs) {
        let display = md_selected_display_range(run, source)
        if (display.start_byte < 0 || display.end_byte <= display.start_byte) continue
        let shown = slice(content.text, display.start_byte, display.end_byte)
        block_plain = block_plain + shown
        if (run.is_link || run.is_image) {
            md_export_uri(result.uri_list, run.destination)
        }
        if (run.is_image) {
            var image_html = "<img src=\"{run.destination |> md_html_attribute()}\" alt=\"{shown |> md_html_attribute()}\""
            if (!empty(run.title)) {
                image_html = image_html + " title=\"{run.title |> md_html_attribute()}\""
            }
            block_html = block_html + image_html + ">"
            var image_markdown = "![{shown |> md_markdown_text()}]({run.destination |> md_markdown_destination()}"
            if (!empty(run.title)) {
                let escaped_title = run.title |> replace("\"", "\\\"")
                image_markdown = image_markdown + " \"" + escaped_title + "\""
            }
            block_markdown = block_markdown + image_markdown + ")"
            continue
        }
        var markdown_text = run.is_code ? shown : (shown |> md_markdown_text())
        if (run.is_code) {
            markdown_text = "`" + markdown_text + "`"
        }
        if (run.is_strikethrough) {
            markdown_text = "~~" + markdown_text + "~~"
        }
        if (run.is_emphasis) {
            markdown_text = "*" + markdown_text + "*"
        }
        if (run.is_strong) {
            markdown_text = "**" + markdown_text + "**"
        }
        if (run.is_link) {
            markdown_text = "[" + markdown_text + "](" + (run.destination |> md_markdown_destination()) + ")"
        }
        block_markdown = block_markdown + markdown_text
        var prefix = ""
        var suffix = ""
        if (run.is_link) {
            prefix = prefix + "<a href=\"{run.destination |> md_html_attribute()}\">"
            suffix = "</a>" + suffix
        }
        if (run.is_strong) { prefix = prefix + "<strong>"; suffix = "</strong>" + suffix }
        if (run.is_emphasis) { prefix = prefix + "<em>"; suffix = "</em>" + suffix }
        if (run.is_strikethrough) { prefix = prefix + "<del>"; suffix = "</del>" + suffix }
        if (run.is_code) { prefix = prefix + "<code>"; suffix = "</code>" + suffix }
        block_html = block_html + prefix + (shown |> md_html_text()) + suffix
    }
    if (empty(block_plain) && empty(block_html)) return
    if (result.block_count > 0) {
        result.plain_text = result.plain_text + "\n"
        result.markdown = result.markdown + "\n"
        result.html = result.html + "<br>\n"
    }
    result.plain_text = result.plain_text + block_plain
    result.markdown = result.markdown + block_markdown
    result.html = result.html + block_html
    result.block_count++
}

def public md_source_text(doc : MdDocument const; source : TextSourceRange const) : string {
    //! Slice a validated original-source range, useful for comment anchors and
    //! persistence. This returns Markdown bytes, not flattened display text.
    if (source.start_byte < 0 || source.end_byte < source.start_byte
            || source.end_byte > length(doc.source)) return ""
    return slice(doc.source, source.start_byte, source.end_byte)
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
