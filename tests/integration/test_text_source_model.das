options gen2
options indenting = 4

require dastest/testing_boost public
require imgui/imgui_text_source_model public
require strings

def private marker_text(document : TextSourceDocument const) : string {
    var result = ""
    for (span in document.spans) {
        if (!span.styles.marker) continue
        if (!empty(result)) {
            result = result + "|"
        }
        result = result + slice(document.source,
            span.source.start_byte, span.source.end_byte)
    }
    return result
}

[test]
def test_markdown_source_markers_preserve_original_bytes(t : T?) {
    let source = "# Heading\n**bold** and `code` [link](target) 👩‍💻\n- item\n"
    var document <- markdown_source_document(source, 7)
    t |> equal(document.source, source, "source model retains exact UTF-8 text")
    t |> equal(document.revision, 7, "caller document revision is retained")
    let markers = marker_text(document)
    t |> success(find(markers, "#|**|**|`|`|[|]|(") == 0,
                 "Markdown delimiter spans are recognized in source order")
    t |> success(ends_with(markers, ")|-"),
                 "link close and list marker complete the delimiter sequence")
    for (i in range(length(document.spans))) {
        let span = document.spans[i]
        var expected_start = 0
        if (i > 0) {
            expected_start = document.spans[i - 1].source.end_byte
        }
        t |> equal(span.source.start_byte, expected_start,
                   "source style spans are contiguous")
        t |> equal(span.styles.marker, span.styles.bold,
                   "every Markdown marker requests bold source weight")
    }
    t |> equal(document.spans[length(document.spans) - 1].source.end_byte,
               length(source), "style spans cover every source byte")
    text_source_document_dispose(document)
}

[test]
def test_markdown_source_escaped_marker_stays_regular(t : T?) {
    let source = "escaped \\* regular; ~~strike~~; > quote"
    var document <- markdown_source_document(source)
    let markers = marker_text(document)
    t |> equal(markers, "\\|~~|~~",
               "escape and paired strike delimiters are markers without styling escaped '*'")
    text_source_document_dispose(document)
}
