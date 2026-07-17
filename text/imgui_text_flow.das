options gen2
options indenting = 4
options no_unused_function_arguments = false

module imgui_text_flow shared

require math
require daslib/strings_boost

//! View-independent UTF-8 inline-flow primitives used by dasImgui's Markdown,
//! editor, and terminal-facing components. Source positions are always UTF-8
//! byte offsets; screen-space output is a flat list of line fragments.
//!
//! Grapheme grouping deliberately lives here rather than in a renderer. The
//! current implementation covers the clusters that matter most for UI input:
//! combining marks, variation selectors, emoji modifiers, ZWJ sequences,
//! regional-indicator flags, keycaps, and Hangul syllable composition. The API
//! is intentionally independent of the implementation so a generated Unicode
//! property table can replace these predicates without changing consumers.

struct public TextSourceRange {
    start_byte : int
    end_byte : int
}

struct public TextGrapheme {
    source : TextSourceRange
    first_codepoint : uint
    last_codepoint : uint
}

struct public TextFlowSpan {
    //! UTF-8 source bytes belonging to this semantic/style run.
    source : TextSourceRange
    style_id : int
    semantic_id : int = -1

    //! Adds URI-friendly opportunities after '/', '?', '&', '#', '=', '-',
    //! '_', '.', ':', and '%'. Natural whitespace wrapping remains enabled.
    uri_wrap : bool = false

    //! Optional inline control placed immediately after this span. Its space is
    //! always part of layout even when the renderer chooses not to draw it.
    trailing_control_id : int = -1
    trailing_control_size : float2
}

struct public TextFlowFragment {
    source : TextSourceRange
    style_id : int
    semantic_id : int
    line_index : int
    rect : float4                 //!< local (x0, y0, x1, y1)
    control_id : int = -1
    is_control : bool = false
}

struct public TextFlowLine {
    first_fragment : int
    fragment_count : int
    source : TextSourceRange
    y : float
    width : float
    height : float
}

struct public TextFlowLayout {
    lines : array<TextFlowLine>
    fragments : array<TextFlowFragment>
    size : float2
}

enum public TextUriKind {
    absolute
    www
}

struct public TextUri {
    source : TextSourceRange
    kind : TextUriKind = TextUriKind.absolute
}

struct private TextScalar {
    source : TextSourceRange
    codepoint : uint
}

struct private TextFlowUnit {
    source : TextSourceRange
    style_id : int
    semantic_id : int
    width : float
    height : float
    break_after : bool
    hard_break : bool
    control_id : int = -1
    is_control : bool = false
}

def private continuation_byte(b : uint) : bool {
    return (b & 0xC0u) == 0x80u
}

def private ascii_alpha(b : uint) : bool {
    return ((b >= uint('A') && b <= uint('Z'))
        || (b >= uint('a') && b <= uint('z')))
}

def private ascii_digit(b : uint) : bool {
    return b >= uint('0') && b <= uint('9')
}

def private uri_boundary_before(bytes : array<uint8> const#; at : int) : bool {
    if (at <= 0) return true
    let b = uint(bytes[at - 1])
    return b < 0x80u && !ascii_alpha(b) && !ascii_digit(b) && b != uint('_')
}

def private starts_ascii_ci(bytes : array<uint8> const#; at : int; value : string) : bool {
    if (at < 0 || at + length(value) > length(bytes)) return false
    var matches = true
    peek_data(value) $(expected) {
        for (i in range(length(expected))) {
            var a = uint(bytes[at + i])
            var b = uint(expected[i])
            if (a >= uint('A') && a <= uint('Z')) {
                a += 32u
            }
            if (b >= uint('A') && b <= uint('Z')) {
                b += 32u
            }
            if (a != b) {
                matches = false
            }
        }
    }
    return matches
}

def private known_uri_scheme(value : string) : bool {
    let lower = to_lower(value)
    return (lower == "http" || lower == "https" || lower == "ftp"
        || lower == "file" || lower == "mailto" || lower == "tel"
        || lower == "urn" || lower == "ssh" || lower == "git"
        || lower == "vscode")
}

def private uri_end(bytes : array<uint8> const#; start : int) : int {
    var at = start
    var parens = 0
    while (at < length(bytes)) {
        let b = uint(bytes[at])
        if (b <= 0x20u || b == uint('"') || b == uint('\'')
                || b == uint('<') || b == uint('>') || b == uint('`')
                || b == uint('[') || b == uint(']')
                || b == uint('{') || b == uint('}')) break
        if (b == uint('(')) {
            parens++
        } elif (b == uint(')')) {
            if (parens == 0) break
            parens--
        }
        at++
    }
    while (at > start) {
        let b = uint(bytes[at - 1])
        if (b == uint('.') || b == uint(',') || b == uint(';')
                || b == uint('!') || b == uint('?') || b == uint(':')) {
            at--
        } else {
            break
        }
    }
    return at
}

def public text_uris(text : string) : array<TextUri> {
    //! Find URI-shaped spans in arbitrary UTF-8 text. This intentionally lives
    //! below Markdown: terminals, editors, logs, and Markdown text leaves all
    //! need identical recognition. Unicode bytes are accepted in the URI body;
    //! surrounding punctuation is excluded conservatively.
    var out : array<TextUri>
    peek_data(text) $(bytes) {
        var at = 0
        while (at < length(bytes)) {
            if (!uri_boundary_before(bytes, at)) {
                at++
                continue
            }
            var body = -1
            var kind = TextUriKind.absolute
            if (starts_ascii_ci(bytes, at, "www.")) {
                body = at + 4
                kind = TextUriKind.www
            } elif (ascii_alpha(uint(bytes[at]))) {
                var colon = at + 1
                while (colon < length(bytes)) {
                    let b = uint(bytes[colon])
                    if (!ascii_alpha(b) && !ascii_digit(b)
                            && b != uint('+') && b != uint('-') && b != uint('.')) break
                    colon++
                }
                if (colon < length(bytes) && uint(bytes[colon]) == uint(':')) {
                    let slash_form = (colon + 2 < length(bytes)
                        && uint(bytes[colon + 1]) == uint('/')
                        && uint(bytes[colon + 2]) == uint('/'))
                    if (slash_form || known_uri_scheme(slice(text, at, colon))) {
                        body = slash_form ? colon + 3 : colon + 1
                    }
                }
            }
            if (body >= 0) {
                let end_ = uri_end(bytes, body)
                if (end_ > body) {
                    out |> push(TextUri(
                        source = TextSourceRange(start_byte = at, end_byte = end_),
                        kind = kind))
                    at = end_
                    continue
                }
            }
            at++
        }
    }
    return <- out
}

def private decode_scalars(text : string; var out : array<TextScalar>) {
    peek_data(text) $(bytes) {
        let n = length(bytes)
        var i = 0
        while (i < n) {
            let start = i
            let b0 = uint(bytes[i])
            var cp = 0xFFFDu
            var count = 1
            if (b0 < 0x80u) {
                cp = b0
            } elif (b0 >= 0xC2u && b0 <= 0xDFu && i + 1 < n
                    && continuation_byte(uint(bytes[i + 1]))) {
                cp = ((b0 & 0x1Fu) << 6u) | (uint(bytes[i + 1]) & 0x3Fu)
                count = 2
            } elif (b0 >= 0xE0u && b0 <= 0xEFu && i + 2 < n
                    && continuation_byte(uint(bytes[i + 1]))
                    && continuation_byte(uint(bytes[i + 2]))) {
                let b1 = uint(bytes[i + 1])
                let valid = ((b0 != 0xE0u || b1 >= 0xA0u)
                         && (b0 != 0xEDu || b1 < 0xA0u))
                if (valid) {
                    cp = (((b0 & 0x0Fu) << 12u) | ((b1 & 0x3Fu) << 6u)
                       | (uint(bytes[i + 2]) & 0x3Fu))
                    count = 3
                }
            } elif (b0 >= 0xF0u && b0 <= 0xF4u && i + 3 < n
                    && continuation_byte(uint(bytes[i + 1]))
                    && continuation_byte(uint(bytes[i + 2]))
                    && continuation_byte(uint(bytes[i + 3]))) {
                let b1 = uint(bytes[i + 1])
                let valid = ((b0 != 0xF0u || b1 >= 0x90u)
                         && (b0 != 0xF4u || b1 < 0x90u))
                if (valid) {
                    cp = (((b0 & 0x07u) << 18u) | ((b1 & 0x3Fu) << 12u)
                       | ((uint(bytes[i + 2]) & 0x3Fu) << 6u)
                       | (uint(bytes[i + 3]) & 0x3Fu))
                    count = 4
                }
            }
            i += count
            out |> push(TextScalar(
                source = TextSourceRange(start_byte = start, end_byte = i),
                codepoint = cp))
        }
    }
}

def private in_range(cp, lo, hi : uint) : bool {
    return cp >= lo && cp <= hi
}

def private is_control(cp : uint) : bool {
    return (cp == 0x000Au || cp == 0x000Du
        || in_range(cp, 0x0000u, 0x001Fu)
        || in_range(cp, 0x007Fu, 0x009Fu))
}

def private is_extend(cp : uint) : bool {
    // Common combining ranges plus all variation selectors, emoji modifiers,
    // combining enclosing keycap, and emoji tag characters.
    return (in_range(cp, 0x0300u, 0x036Fu)
        || in_range(cp, 0x0483u, 0x0489u)
        || in_range(cp, 0x0591u, 0x05BDu) || cp == 0x05BFu
        || in_range(cp, 0x05C1u, 0x05C2u) || in_range(cp, 0x05C4u, 0x05C5u)
        || in_range(cp, 0x0610u, 0x061Au) || in_range(cp, 0x064Bu, 0x065Fu)
        || cp == 0x0670u || in_range(cp, 0x06D6u, 0x06EDu)
        || in_range(cp, 0x0711u, 0x0711u) || in_range(cp, 0x0730u, 0x074Au)
        || in_range(cp, 0x07A6u, 0x07B0u) || in_range(cp, 0x07EBu, 0x07F3u)
        || in_range(cp, 0x0816u, 0x082Du) || in_range(cp, 0x0859u, 0x085Bu)
        || in_range(cp, 0x08D3u, 0x0902u)
        || in_range(cp, 0x093Au, 0x093Cu) || in_range(cp, 0x0941u, 0x0948u)
        || in_range(cp, 0x094Du, 0x094Du) || in_range(cp, 0x0951u, 0x0957u)
        || in_range(cp, 0x0962u, 0x0963u)
        || in_range(cp, 0x1AB0u, 0x1AFFu)
        || in_range(cp, 0x1DC0u, 0x1DFFu)
        || in_range(cp, 0x20D0u, 0x20FFu)
        || in_range(cp, 0xFE00u, 0xFE0Fu)
        || in_range(cp, 0xFE20u, 0xFE2Fu)
        || in_range(cp, 0x1F3FBu, 0x1F3FFu)
        || in_range(cp, 0xE0020u, 0xE007Fu)
        || in_range(cp, 0xE0100u, 0xE01EFu))
}

def private is_spacing_mark(cp : uint) : bool {
    // High-value Mc ranges. These prevent caret stops inside the visible
    // consonant/vowel cluster while keeping the table compact for now.
    return (cp == 0x0903u || in_range(cp, 0x093Bu, 0x0940u)
        || in_range(cp, 0x0949u, 0x094Cu) || in_range(cp, 0x0982u, 0x0983u)
        || in_range(cp, 0x09BEu, 0x09C0u) || in_range(cp, 0x09C7u, 0x09C8u)
        || in_range(cp, 0x09CBu, 0x09CCu) || in_range(cp, 0x0A3Eu, 0x0A40u)
        || in_range(cp, 0x0ABEu, 0x0AC0u) || in_range(cp, 0x0B3Eu, 0x0B40u)
        || in_range(cp, 0x0BBEu, 0x0BC2u) || in_range(cp, 0x0BC6u, 0x0BC8u)
        || in_range(cp, 0x0BCAu, 0x0BCCu) || in_range(cp, 0x0C01u, 0x0C03u)
        || in_range(cp, 0x0C41u, 0x0C44u) || in_range(cp, 0x0D3Eu, 0x0D40u)
        || in_range(cp, 0x0D46u, 0x0D48u) || in_range(cp, 0x0D4Au, 0x0D4Cu))
}

def private is_prepend(cp : uint) : bool {
    return (in_range(cp, 0x0600u, 0x0605u) || cp == 0x06DDu || cp == 0x070Fu
        || cp == 0x08E2u || cp == 0x110BDu || in_range(cp, 0x111C2u, 0x111C3u))
}

def private is_regional_indicator(cp : uint) : bool {
    return in_range(cp, 0x1F1E6u, 0x1F1FFu)
}

def private is_hangul_l(cp : uint) : bool {
    return in_range(cp, 0x1100u, 0x115Fu) || in_range(cp, 0xA960u, 0xA97Cu)
}

def private is_hangul_v(cp : uint) : bool {
    return in_range(cp, 0x1160u, 0x11A7u) || in_range(cp, 0xD7B0u, 0xD7C6u)
}

def private is_hangul_t(cp : uint) : bool {
    return in_range(cp, 0x11A8u, 0x11FFu) || in_range(cp, 0xD7CBu, 0xD7FBu)
}

def private is_hangul_lv(cp : uint) : bool {
    return in_range(cp, 0xAC00u, 0xD7A3u) && ((cp - 0xAC00u) % 28u) == 0u
}

def private is_hangul_lvt(cp : uint) : bool {
    return in_range(cp, 0xAC00u, 0xD7A3u) && ((cp - 0xAC00u) % 28u) != 0u
}

def private should_break_grapheme(prev, cur : uint; regional_run : int) : bool {
    if (prev == 0x000Du && cur == 0x000Au) return false
    if (is_control(prev) || is_control(cur)) return true

    if (is_hangul_l(prev) && (is_hangul_l(cur) || is_hangul_v(cur)
            || is_hangul_lv(cur) || is_hangul_lvt(cur))) return false
    if ((is_hangul_lv(prev) || is_hangul_v(prev))
            && (is_hangul_v(cur) || is_hangul_t(cur))) return false
    if ((is_hangul_lvt(prev) || is_hangul_t(prev)) && is_hangul_t(cur)) return false

    if (is_prepend(prev)) return false
    if (is_extend(cur) || is_spacing_mark(cur) || cur == 0x200Du) return false
    // Joining the character following ZWJ is intentionally broad. It keeps
    // emoji families and profession sequences atomic; a later generated UCD
    // table can narrow this to Extended_Pictographic exactly.
    if (prev == 0x200Du) return false

    if (is_regional_indicator(prev) && is_regional_indicator(cur)) {
        return (regional_run % 2) == 0
    }
    return true
}

def public text_graphemes(text : string) : array<TextGrapheme> {
    var scalars : array<TextScalar>
    decode_scalars(text, scalars)
    var out : array<TextGrapheme>
    if (empty(scalars)) {
        delete scalars
        return <- out
    }

    var cluster_start = 0
    var regional_run = is_regional_indicator(scalars[0].codepoint) ? 1 : 0
    for (i in range(1, length(scalars))) {
        let prev = scalars[i - 1].codepoint
        let cur = scalars[i].codepoint
        let split = should_break_grapheme(prev, cur, regional_run)
        if (split) {
            out |> push(TextGrapheme(
                source = TextSourceRange(
                    start_byte = scalars[cluster_start].source.start_byte,
                    end_byte = scalars[i - 1].source.end_byte),
                first_codepoint = scalars[cluster_start].codepoint,
                last_codepoint = prev))
            cluster_start = i
            regional_run = is_regional_indicator(cur) ? 1 : 0
        } elif (is_regional_indicator(cur)) {
            regional_run++
        } elif (!is_extend(cur) && cur != 0x200Du) {
            regional_run = 0
        }
    }
    out |> push(TextGrapheme(
        source = TextSourceRange(
            start_byte = scalars[cluster_start].source.start_byte,
            end_byte = scalars[length(scalars) - 1].source.end_byte),
        first_codepoint = scalars[cluster_start].codepoint,
        last_codepoint = scalars[length(scalars) - 1].codepoint))
    delete scalars
    return <- out
}

def private natural_break_after(cp : uint) : bool {
    return cp == 0x0020u || cp == 0x0009u || cp == 0x200Bu
}

def private uri_break_after(cp : uint) : bool {
    return (cp == uint('/') || cp == uint('?') || cp == uint('&')
        || cp == uint('#') || cp == uint('=') || cp == uint('-')
        || cp == uint('_') || cp == uint('.') || cp == uint(':')
        || cp == uint('%'))
}

def private make_units(source : string; spans : array<TextFlowSpan> const;
                       line_height : float;
                       measure : block<(text : string; start_byte : int;
                                        end_byte : int; style_id : int) : float>) : array<TextFlowUnit> {
    var units : array<TextFlowUnit>
    let source_len = length(source)
    for (span in spans) {
        let a = clamp(span.source.start_byte, 0, source_len)
        let b = clamp(span.source.end_byte, a, source_len)
        var span_text := slice(source, a, b)
        var graphemes <- text_graphemes(span_text)
        for (g in graphemes) {
            let ga = a + g.source.start_byte
            let gb = a + g.source.end_byte
            let hard = g.first_codepoint == 0x000Au || g.first_codepoint == 0x000Du
            let measured_width = (hard ? 0.0f
                : invoke(measure, source, ga, gb, span.style_id))
            units |> push(TextFlowUnit(
                source = TextSourceRange(start_byte = ga, end_byte = gb),
                style_id = span.style_id,
                semantic_id = span.semantic_id,
                width = measured_width,
                height = line_height,
                break_after = natural_break_after(g.last_codepoint)
                    || (span.uri_wrap && uri_break_after(g.last_codepoint)),
                hard_break = hard))
        }
        delete graphemes
        if (span.trailing_control_id >= 0 && span.trailing_control_size.x > 0.0f) {
            units |> push(TextFlowUnit(
                source = TextSourceRange(start_byte = b, end_byte = b),
                style_id = span.style_id,
                semantic_id = span.semantic_id,
                width = span.trailing_control_size.x,
                height = max(line_height, span.trailing_control_size.y),
                break_after = true,
                hard_break = false,
                control_id = span.trailing_control_id,
                is_control = true))
        }
    }
    return <- units
}

def private push_fragment(var layout : TextFlowLayout; units : array<TextFlowUnit> const;
                          first, end_, line_index : int; x, y, line_height : float) : float {
    let u0 = units[first]
    var width = 0.0f
    for (i in range(first, end_)) {
        width += units[i].width
    }

    var rect_y = y
    var rect_h = line_height
    if (u0.is_control) {
        rect_h = u0.height
        rect_y = y + (line_height - rect_h) * 0.5f
    }
    layout.fragments |> push(TextFlowFragment(
        source = TextSourceRange(
            start_byte = u0.source.start_byte,
            end_byte = units[end_ - 1].source.end_byte),
        style_id = u0.style_id,
        semantic_id = u0.semantic_id,
        line_index = line_index,
        rect = float4(x, rect_y, x + width, rect_y + rect_h),
        control_id = u0.control_id,
        is_control = u0.is_control))
    return width
}

def private emit_line(var layout : TextFlowLayout; units : array<TextFlowUnit> const;
                      first, end_ : int; y, fallback_height : float) : float {
    var line_height = fallback_height
    var line_width = 0.0f
    for (i in range(first, end_)) {
        line_height = max(line_height, units[i].height)
        line_width += units[i].width
    }

    let first_fragment = length(layout.fragments)
    let line_index = length(layout.lines)
    var x = 0.0f
    var fragment_start = first
    var i = first
    while (i < end_) {
        let a = units[fragment_start]
        let b = units[i]
        var same = false
        if (i > fragment_start) {
            same = (!a.is_control && !b.is_control
                && a.style_id == b.style_id && a.semantic_id == b.semantic_id
                && units[i - 1].source.end_byte == b.source.start_byte)
        }
        if (i > fragment_start && !same) {
            x += push_fragment(layout, units, fragment_start, i,
                               line_index, x, y, line_height)
            fragment_start = i
        }
        if (b.is_control) {
            if (i > fragment_start) {
                x += push_fragment(layout, units, fragment_start, i,
                                   line_index, x, y, line_height)
            }
            x += push_fragment(layout, units, i, i + 1,
                               line_index, x, y, line_height)
            fragment_start = i + 1
        }
        i++
    }
    if (fragment_start < end_) {
        push_fragment(layout, units, fragment_start, end_,
                      line_index, x, y, line_height)
    }

    var source_start = first < end_ ? units[first].source.start_byte : 0
    var source_end = first < end_ ? units[end_ - 1].source.end_byte : source_start
    layout.lines |> push(TextFlowLine(
        first_fragment = first_fragment,
        fragment_count = length(layout.fragments) - first_fragment,
        source = TextSourceRange(start_byte = source_start, end_byte = source_end),
        y = y,
        width = line_width,
        height = line_height))
    return line_height
}

def private layout_units(units : array<TextFlowUnit> const;
                         max_width, line_height : float) : TextFlowLayout {
    var layout : TextFlowLayout
    let width_limit = max(max_width, 1.0f)
    var start = 0
    var y = 0.0f
    var widest = 0.0f

    while (start < length(units)) {
        if (units[start].hard_break) {
            let h = emit_line(layout, units, start, start, y, line_height)
            y += h
            start++
            continue
        }

        var i = start
        var width = 0.0f
        var last_break = -1
        var end_ = start
        var consumed_hard_break = false
        while (i < length(units)) {
            if (units[i].hard_break) {
                end_ = i
                consumed_hard_break = true
                break
            }
            let next_width = width + units[i].width
            if (next_width > width_limit && i > start) {
                end_ = last_break > start ? last_break : i
                break
            }
            width = next_width
            if (units[i].break_after) {
                last_break = i + 1
            }
            i++
            end_ = i
            if (width > width_limit) break // one oversized grapheme/control
        }

        let h = emit_line(layout, units, start, end_, y, line_height)
        widest = max(widest, layout.lines[length(layout.lines) - 1].width)
        y += h
        start = end_
        if (consumed_hard_break && start < length(units) && units[start].hard_break) {
            start++
        }
    }

    layout.size = float2(min(widest, width_limit), y)
    return <- layout
}

def public layout_text_flow_styled_ranges(source : string;
                                          spans : array<TextFlowSpan> const;
                                          max_width, line_height : float;
                                          measure : block<(text : string;
                                              start_byte : int; end_byte : int;
                                              style_id : int) : float>) : TextFlowLayout {
    //! Greedy inline layout with style-aware measurement. Text is never split
    //! inside a grapheme cluster; the measured style is carried unchanged into
    //! each emitted fragment so rendering can use the identical font role.
    var units <- make_units(source, spans, line_height, measure)
    var layout <- layout_units(units, max_width, line_height)
    delete units
    return <- layout
}

def public layout_text_flow_styled(source : string; spans : array<TextFlowSpan> const;
                                   max_width, line_height : float;
                                   measure : block<(text : string; style_id : int) : float>) : TextFlowLayout {
    return <- layout_text_flow_styled_ranges(source, spans, max_width, line_height,
        $(text : string; start_byte : int; end_byte : int; style_id : int) : float {
            var value := slice(text, start_byte, end_byte)
            let width = invoke(measure, value, style_id)
            return width
        })
}

def public layout_text_flow(source : string; spans : array<TextFlowSpan> const;
                            max_width, line_height : float;
                            measure : block<(text : string) : float>) : TextFlowLayout {
    //! Compatibility overload for consumers whose styles share one font.
    return <- layout_text_flow_styled(source, spans, max_width, line_height,
        $(text : string; style_id : int) : float {
            return invoke(measure, text)
        })
}
