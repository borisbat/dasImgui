options gen2
options indenting = 4

require dastest/testing_boost public
require imgui/imgui_text_flow public
require strings

//! Headless contract tests for the shared Markdown/editor/terminal text layer.
//! These intentionally do not create an ImGui context: layout consumes a
//! measurement callback and emits source-mapped fragments.

[test]
def test_text_flow_graphemes(t : T?) {
    // e + COMBINING ACUTE, woman-technologist ZWJ sequence, and a two-RI flag
    // are each one caret/wrap unit despite occupying multiple UTF-8 scalars.
    let source = "Aé👩‍💻🇺🇸B"
    let g <- text_graphemes(source)
    t |> equal(length(g), 5, "extended UI grapheme grouping")
    if (length(g) != 5) return

    t |> equal(g[1].source.start_byte, 1, "combining cluster starts at e")
    t |> equal(g[1].source.end_byte, 4, "combining cluster includes U+0301")
    t |> equal(g[2].source.start_byte, 4, "ZWJ emoji starts after combining cluster")
    t |> equal(g[2].source.end_byte, 15, "ZWJ emoji is one 11-byte cluster")
    t |> equal(g[3].source.start_byte, 15, "flag starts after ZWJ emoji")
    t |> equal(g[3].source.end_byte, 23, "regional-indicator pair is one cluster")
}

[test]
def test_text_flow_uri_fragments(t : T?) {
    let prefix = "Open "
    let uri = "https://example.com/文档/a-long-name?q=é&mode=full"
    let suffix = " safely."
    let source = prefix + uri + suffix
    let uri_start = length(prefix)
    let uri_end = uri_start + length(uri)

    var spans = [
        TextFlowSpan(
            source = TextSourceRange(start_byte = 0, end_byte = uri_start),
            style_id = 0),
        TextFlowSpan(
            source = TextSourceRange(start_byte = uri_start, end_byte = uri_end),
            style_id = 1, semantic_id = 42, uri_wrap = true,
            trailing_control_id = 7,
            trailing_control_size = float2(16.0f, 16.0f)),
        TextFlowSpan(
            source = TextSourceRange(start_byte = uri_end, end_byte = length(source)),
            style_id = 0)
    ]

    // Deterministic fake font: every grapheme advances 8 px. It makes the core
    // test independent of the machine's atlas while exercising Unicode input.
    let layout <- layout_text_flow(source, spans, 96.0f, 18.0f,
        $(s : string) : float {
            return float(length(text_graphemes(s))) * 8.0f
        })

    t |> success(length(layout.lines) > 1, "long URI wraps to multiple lines")
    var control_count = 0
    var uri_fragment_count = 0
    var all_lines_fit = true
    for (line in layout.lines) {
        if (line.width > 96.01f) {
            all_lines_fit = false
        }
    }
    for (fragment in layout.fragments) {
        if (fragment.is_control) {
            control_count++
            t |> equal(fragment.control_id, 7, "reserved control preserves its identity")
            t |> equal(fragment.semantic_id, 42, "reserved control belongs to the URI")
            t |> equal(fragment.source.start_byte, uri_end, "control anchors after URI source")
            t |> equal(fragment.source.end_byte, uri_end, "control consumes no source bytes")
        } elif (fragment.semantic_id == 42) {
            uri_fragment_count++
            t |> success(fragment.source.start_byte >= uri_start
                       && fragment.source.end_byte <= uri_end,
                       "URI visual fragment maps into URI source")
        }
    }
    t |> success(all_lines_fit, "greedy wrapping respects available width")
    t |> success(uri_fragment_count > 1,
                 "one semantic URI produces multiple visual fragments")
    t |> equal(control_count, 1, "copy control reserves exactly one inline slot")
}
