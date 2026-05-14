options gen2
options indenting = 4

module imgui_colors shared

require imgui public

// Stand-alone packer for ImGui's IM_COL32 byte order, decoupled from
// the legacy v1 `daslib/imgui_boost.das`. Pulls only the imgui module
// (for the shift constants). dasIMGUI is compiled with
// `IMGUI_USE_BGRA_PACKED_COLOR`, so `R_SHIFT=16`, `B_SHIFT=0`; the
// renderer decodes the same word order, so colors round-trip.

def rgba(r, g, b, a : int) : uint {
    return ((uint(a) << uint(IM_COL32_A_SHIFT))
          | (uint(r) << uint(IM_COL32_R_SHIFT))
          | (uint(g) << uint(IM_COL32_G_SHIFT))
          | (uint(b) << uint(IM_COL32_B_SHIFT)))
}

def rgba(r, g, b, a : uint) : uint {
    return ((a << uint(IM_COL32_A_SHIFT))
          | (r << uint(IM_COL32_R_SHIFT))
          | (g << uint(IM_COL32_G_SHIFT))
          | (b << uint(IM_COL32_B_SHIFT)))
}

let IM_COL32_WHITE = rgba(255u, 255u, 255u, 255u)
let IM_COL32_BLACK = rgba(0u, 0u, 0u, 255u)
let IM_COL32_BLACK_TRANS = rgba(0u, 0u, 0u, 0u)
