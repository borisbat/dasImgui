options gen2

module imgui_fonts

require imgui public
require daslib/fio
require daslib/module_path

// ImGuiFreeTypeLoaderFlags_ lives in optional imgui_freetype.h and is not part
// of the generated imgui.h binding. Keep these public names aligned with that
// upstream enum so callers never need magic bit values.
let public IMGUI_FREETYPE_LOAD_COLOR = 1u << 8

def private bundled_mono_font_path() : string {
    if (get_running_platform_name() == "emscripten") {
        return "/modules/dasImgui/font/JetBrainsMono-Regular.ttf"
    }
    return path_join(dir_name(get_this_module_dir()), "font/JetBrainsMono-Regular.ttf")
}

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

def public merge_font_from_file(path : string; size_px : float; pixel_snap_h : bool = true;
                                font_loader_flags : uint = 0u) : bool {
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
        cfg.FontLoaderFlags = font_loader_flags
        return (atlas |> AddFontFromFileTTF(path, size_px, addr(cfg), null)) != null
    }
}

def private merge_unicode_source(path : string; size_px : float;
                                 var loaded_sources : array<string>;
                                 font_loader_flags : uint = 0u) {
    if (merge_font_from_file(path, size_px, true, font_loader_flags)) {
        loaded_sources |> push(path)
    }
}

def public load_unicode_ui_font(size_px : float;
                                var loaded_sources : array<string>) : ImFont? {
    //! Build the shared terminal/editor/Markdown font stack. Windows uses
    //! Consolas as its primary face to match the local Terminal profile;
    //! other platforms keep dasImgui's bundled JetBrains Mono base. Missing
    //! fallback files are harmless and omitted from ``loaded_sources``.
    let windows_consolas = "C:/Windows/Fonts/consola.ttf"
    let base = (get_running_platform_name() == "windows" && font_file_exists(windows_consolas)
        ? windows_consolas : bundled_mono_font_path())
    var font = load_font_from_file(base, size_px)
    if (font != null) {
        loaded_sources |> push(base)
    }

    // First face wins for overlapping glyphs. Keep the color emoji face ahead
    // of Segoe UI Symbol so COLR/CPAL layers are retained.
    if (get_running_platform_name() == "windows") {
        merge_unicode_source("C:/Windows/Fonts/seguiemj.ttf", size_px,
                             loaded_sources, IMGUI_FREETYPE_LOAD_COLOR)
        merge_unicode_source("C:/Windows/Fonts/seguisym.ttf", size_px, loaded_sources)
        merge_unicode_source("C:/Windows/Fonts/NotoSans-Regular.ttf", size_px, loaded_sources)
        merge_unicode_source("C:/Windows/Fonts/NotoSansJP-Regular.ttf", size_px, loaded_sources)
        merge_unicode_source("C:/Windows/Fonts/msyh.ttc", size_px, loaded_sources)
        merge_unicode_source("C:/Windows/Fonts/malgun.ttf", size_px, loaded_sources)
        merge_unicode_source("C:/Windows/Fonts/NotoSansHebrew-Regular.ttf", size_px, loaded_sources)
        merge_unicode_source("C:/Windows/Fonts/NotoSansArabic-Regular.ttf", size_px, loaded_sources)
    } elif (get_running_platform_name() == "osx") {
        merge_unicode_source("/System/Library/Fonts/Apple Symbols.ttf", size_px, loaded_sources)
        merge_unicode_source("/System/Library/Fonts/Apple Color Emoji.ttc", size_px, loaded_sources)
        merge_unicode_source("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", size_px, loaded_sources)
    } else {
        merge_unicode_source("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size_px, loaded_sources)
        merge_unicode_source("/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf", size_px, loaded_sources)
        merge_unicode_source("/usr/share/opentype/noto/NotoSansCJK-Regular.ttc", size_px, loaded_sources)
    }
    return font
}
