options gen2

module imgui_fonts

require imgui public
require daslib/fio

def public font_file_exists(path : string) : bool {
    //! True when ``path`` names a readable font candidate. Kept here so
    //! platform fallback discovery does not need raw ImGui access.
    return !empty(path) && stat(path).is_valid
}

def public load_font_from_file(path : string; size_px : float) : ImFont? {
    //! Add a standalone TTF/OTF face to the current atlas. Returns null when
    //! the path is absent or Dear ImGui rejects the face.
    if (!font_file_exists(path)) {
        return null
    }
    var atlas & = unsafe(*GetIO().Fonts)
    var font = atlas |> AddFontFromFileTTF(path, size_px, null, null)
    return font
}

def public font_has_glyph(var font : ImFont?; codepoint : uint) : bool {
    //! Query the full Unicode scalar range. dasImgui is built with 32-bit
    //! ImWchar, so supplementary-plane codepoints are not truncated here.
    if (font == null) {
        return false
    }
    return *font |> IsGlyphInFont(codepoint)
}

def public merge_font_from_file(path : string; size_px : float; pixel_snap_h : bool = true) : bool {
    //! Merge a TTF/OTF face into the most recently added font. Dear ImGui has
    //! no platform font fallback: adding multiple sources in merge mode is
    //! how one font gains symbols and language ranges from fallback faces.
    if (!font_file_exists(path)) {
        return false
    }
    var atlas & = unsafe(*GetIO().Fonts)
    unsafe {
        var cfg = ImFontConfig()
        cfg.MergeMode = true
        cfg.PixelSnapH = pixel_snap_h
        return (atlas |> AddFontFromFileTTF(path, size_px, addr(cfg), null)) != null
    }
}
