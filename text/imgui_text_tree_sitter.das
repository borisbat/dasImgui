options gen2
options indenting = 4

module imgui_text_tree_sitter shared

require imgui/imgui_text_source_model public
require tree_sitter/tree_sitter public
require math
require strings

//! Optional Tree-sitter producer for the parser-neutral source-view model.
//! The source model and renderer remain usable without a parser provider.

def private source_syntax_style(role : SyntaxRole) : TextSourceSyntaxStyle {
    if (role == SyntaxRole.comment) {
        return TextSourceSyntaxStyle.comment
    } elif (role == SyntaxRole.string_ || role == SyntaxRole.character
            || role == SyntaxRole.escape) {
        return TextSourceSyntaxStyle.string_
    } elif (role == SyntaxRole.number || role == SyntaxRole.boolean_) {
        return TextSourceSyntaxStyle.number
    } elif (role == SyntaxRole.keyword || role == SyntaxRole.attribute
            || role == SyntaxRole.module_) {
        return TextSourceSyntaxStyle.keyword
    } elif (role == SyntaxRole.type_) {
        return TextSourceSyntaxStyle.type_
    } elif (role == SyntaxRole.function_) {
        return TextSourceSyntaxStyle.function_
    } elif (role == SyntaxRole.variable || role == SyntaxRole.parameter
            || role == SyntaxRole.label_) {
        return TextSourceSyntaxStyle.variable
    } elif (role == SyntaxRole.property) {
        return TextSourceSyntaxStyle.property
    } elif (role == SyntaxRole.constant) {
        return TextSourceSyntaxStyle.constant
    } elif (role == SyntaxRole.operator_) {
        return TextSourceSyntaxStyle.operator_
    } elif (role == SyntaxRole.punctuation) {
        return TextSourceSyntaxStyle.punctuation
    }
    return TextSourceSyntaxStyle.none
}

def private push_source_syntax_span(var document : TextSourceDocument;
                                    start_byte, end_byte : int;
                                    style : TextSourceSyntaxStyle) {
    if (end_byte <= start_byte) return
    document.spans |> push(TextSourceSpan(
        source = TextSourceRange(start_byte = start_byte, end_byte = end_byte),
        syntax_style = style))
}

def public tree_sitter_source_document(source, language : string;
                                       revision : int = 0) : TextSourceDocument {
    var document = TextSourceDocument(source = source, revision = revision)
    var tokens : array<SyntaxToken>
    if (syntax_highlight(language, source, tokens) != SyntaxHighlightStatus.ok) {
        delete tokens
        return <- plain_source_document(source, revision)
    }

    var covered_until = 0
    for (token in tokens) {
        let syntax_style = source_syntax_style(token.role)
        if (syntax_style == TextSourceSyntaxStyle.none) continue
        let start_byte = clamp(token.start_byte, covered_until, length(source))
        let end_byte = clamp(token.end_byte, start_byte, length(source))
        push_source_syntax_span(document, covered_until, start_byte,
                                TextSourceSyntaxStyle.none)
        push_source_syntax_span(document, start_byte, end_byte, syntax_style)
        covered_until = end_byte
    }
    push_source_syntax_span(document, covered_until, length(source),
                            TextSourceSyntaxStyle.none)
    delete tokens
    return <- document
}
