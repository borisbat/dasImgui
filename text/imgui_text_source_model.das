options gen2
options indenting = 4

module imgui_text_source_model shared

require imgui/imgui_text_flow public
require strings

//! View-independent styled source text. The source string is never rewritten:
//! every style span refers to exact UTF-8 bytes, so selection, clipboard, and
//! future edits use the same coordinates regardless of presentation.

bitfield public TextSourceStyles {
    marker
    bold
}

struct public TextSourceSpan {
    source : TextSourceRange
    styles : TextSourceStyles
}

struct public TextSourceDocument {
    source : string
    spans : array<TextSourceSpan>
    revision : int = 0
    marker_count : int = 0
}

def public text_source_document_dispose(var document : TextSourceDocument) {
    delete document.spans
    document = TextSourceDocument()
}

def private ascii_markdown_delimiter(b : uint) : bool {
    return (b == uint('*') || b == uint('_') || b == uint('~')
        || b == uint('`') || b == uint('[') || b == uint(']')
        || b == uint('(') || b == uint(')') || b == uint('!'))
}

def private ascii_digit_byte(b : uint) : bool {
    return b >= uint('0') && b <= uint('9')
}

def private push_source_span(var document : TextSourceDocument;
                             start_byte, end_byte : int; marker : bool) {
    if (end_byte <= start_byte) return
    var styles : TextSourceStyles
    styles.marker = marker
    styles.bold = marker
    document.spans |> push(TextSourceSpan(
        source = TextSourceRange(start_byte = start_byte, end_byte = end_byte),
        styles = styles))
    if (marker) {
        document.marker_count++
    }
}

def private push_marker(var document : TextSourceDocument; var covered_until : int&;
                        start_byte, end_byte : int) {
    if (start_byte < covered_until || end_byte <= start_byte) return
    push_source_span(document, covered_until, start_byte, false)
    push_source_span(document, start_byte, end_byte, true)
    covered_until = end_byte
}

def public markdown_source_document(source : string;
                                    revision : int = 0) : TextSourceDocument {
    //! Lightweight Markdown lexical styling for source presentation. This is
    //! intentionally not a second Markdown parser: it recognizes delimiter
    //! tokens while leaving all bytes visible. Structural MD4C parsing remains
    //! the authority for rendered Markdown.
    var document = TextSourceDocument(revision = revision)
    document.source := source
    peek_data(source) $(bytes) {
        let n = length(bytes)
        var at = 0
        var line_start = 0
        var covered_until = 0
        var link_paren_depth = 0
        while (at < n) {
            if (at == line_start) {
                var content = at
                while (content < n && content - at < 3
                        && uint(bytes[content]) == uint(' ')) {
                    content++
                }
                if (content < n) {
                    let first = uint(bytes[content])
                    var marker_end = content
                    if (first == uint('#')) {
                        while (marker_end < n && marker_end - content < 6
                                && uint(bytes[marker_end]) == uint('#')) {
                            marker_end++
                        }
                        if (marker_end < n && uint(bytes[marker_end]) == uint(' ')) {
                            push_marker(document, covered_until, content, marker_end)
                            at = marker_end
                            continue
                        }
                    } elif (first == uint('>')) {
                        push_marker(document, covered_until, content, content + 1)
                        at = content + 1
                        continue
                    } elif ((first == uint('-') || first == uint('+') || first == uint('*'))
                            && content + 1 < n
                            && (uint(bytes[content + 1]) == uint(' ')
                                || uint(bytes[content + 1]) == uint('\t'))) {
                        push_marker(document, covered_until, content, content + 1)
                        at = content + 1
                        continue
                    } elif (ascii_digit_byte(first)) {
                        marker_end = content + 1
                        while (marker_end < n && ascii_digit_byte(uint(bytes[marker_end]))) {
                            marker_end++
                        }
                        if (marker_end + 1 < n
                                && (uint(bytes[marker_end]) == uint('.')
                                    || uint(bytes[marker_end]) == uint(')'))
                                && (uint(bytes[marker_end + 1]) == uint(' ')
                                    || uint(bytes[marker_end + 1]) == uint('\t'))) {
                            push_marker(document, covered_until, content, marker_end + 1)
                            at = marker_end + 1
                            continue
                        }
                    }
                }
            }

            let b = uint(bytes[at])
            if (b == uint('\r') || b == uint('\n')) {
                if (b == uint('\r') && at + 1 < n
                        && uint(bytes[at + 1]) == uint('\n')) {
                    at += 2
                } else {
                    at++
                }
                line_start = at
                continue
            }
            if (b == uint('\\') && at + 1 < n
                    && ascii_markdown_delimiter(uint(bytes[at + 1]))) {
                push_marker(document, covered_until, at, at + 1)
                at += 2 // escaped byte remains regular
                continue
            }
            if (b == uint('*') || b == uint('_') || b == uint('`') || b == uint('~')) {
                var end_ = at + 1
                while (end_ < n && uint(bytes[end_]) == b) {
                    end_++
                }
                if (b != uint('~') || end_ - at >= 2) {
                    push_marker(document, covered_until, at, end_)
                }
                at = end_
                continue
            }
            if (b == uint('[') || b == uint(']') || b == uint('!')) {
                push_marker(document, covered_until, at, at + 1)
            } elif (b == uint('(') && at > 0 && uint(bytes[at - 1]) == uint(']')) {
                push_marker(document, covered_until, at, at + 1)
                link_paren_depth = 1
            } elif (b == uint('(') && link_paren_depth > 0) {
                link_paren_depth++
                push_marker(document, covered_until, at, at + 1)
            } elif (b == uint(')') && link_paren_depth > 0) {
                push_marker(document, covered_until, at, at + 1)
                link_paren_depth--
            }
            at++
        }
        push_source_span(document, covered_until, n, false)
    }
    if (empty(document.spans) && empty(source)) {
        push_source_span(document, 0, 0, false)
    }
    return <- document
}
