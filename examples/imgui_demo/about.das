options gen2
options indenting = 4

module about

require imgui
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require daslib/safe_addr

// Module-scope state — replaces the C++ `static bool show_config_info`.
var ABOUT_SHOW_CONFIG_INFO = false

// Mirrors imgui_demo.cpp:6460-6622 — void ImGui::ShowAboutWindow(bool* p_open).
// Notes on the daslang port:
//   - The ~50 `#ifdef DEFINE_NAME` Text() lines in C++ list compile-time
//     preprocessor defines for the *Dear ImGui C++ build*. They have no
//     meaningful translation to a daslang-hosted demo and are elided.
//   - The C++ pointer-to-clipboard log path is preserved.
def ShowAboutWindow() {
    window(ABOUT_WINDOW, (text = "About Dear ImGui", closable = false,
                          flags = ImGuiWindowFlags.AlwaysAutoResize)) {
        text(ABOUT_VERSION, (text = "Dear ImGui {IMGUI_VERSION} ({IMGUI_VERSION_NUM})"))
        separator(ABOUT_SEP_1)
        text(ABOUT_TEXT_2, (text = "By Omar Cornut and all Dear ImGui contributors."))
        text(ABOUT_TEXT_3, (text = "Dear ImGui is licensed under the MIT License, " +
             "see LICENSE for more information."))
        text(ABOUT_TEXT_4, (text = "If your company uses this, please consider funding the project."))

        Checkbox("Config/Build Information", safe_addr(ABOUT_SHOW_CONFIG_INFO))
        if (ABOUT_SHOW_CONFIG_INFO) {
            let io & = unsafe(GetIO())
            let style & = unsafe(GetStyle())

            let copy_to_clipboard = Button("Copy to clipboard")
            let child_size = float2(0.0f, GetTextLineHeightWithSpacing() * 18.0f)
            BeginChild("cfg_infos", child_size, ImGuiChildFlags.FrameStyle)

            if (copy_to_clipboard) {
                LogToClipboard()
                // Back-quotes wrap the dump so a GitHub-pasted version renders
                // as a code block.
                LogText("```\n")
            }

            text(ABOUT_CFG_VERSION, (text = "Dear ImGui {IMGUI_VERSION} ({IMGUI_VERSION_NUM})"))
            separator(ABOUT_SEP_2)
            text(ABOUT_TEXT_6, (text = "define: __cplusplus elided (daslang port)"))
            text(ABOUT_TEXT_7, (text = "(C++ build-define block elided; see imgui_demo.cpp:6494-6565)"))
            separator(ABOUT_SEP_3)
            text(ABOUT_TEXT_8, (text = "io.BackendPlatformName: {io.BackendPlatformName}"))
            text(ABOUT_TEXT_9, (text = "io.BackendRendererName: {io.BackendRendererName}"))
            text(ABOUT_TEXT_10, (text = "io.ConfigFlags: {fmt_hex(uint(io.ConfigFlags))}"))
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavEnableKeyboard) != 0u) {
                text(ABOUT_TEXT_11, (text = " NavEnableKeyboard"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavEnableGamepad) != 0u) {
                text(ABOUT_TEXT_12, (text = " NavEnableGamepad"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavEnableSetMousePos) != 0u) {
                text(ABOUT_TEXT_13, (text = " NavEnableSetMousePos"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavNoCaptureKeyboard) != 0u) {
                text(ABOUT_TEXT_14, (text = " NavNoCaptureKeyboard"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NoMouse) != 0u) {
                text(ABOUT_TEXT_15, (text = " NoMouse"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NoMouseCursorChange) != 0u) {
                text(ABOUT_TEXT_16, (text = " NoMouseCursorChange"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.DockingEnable) != 0u) {
                text(ABOUT_TEXT_17, (text = " DockingEnable"))
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.ViewportsEnable) != 0u) {
                text(ABOUT_TEXT_18, (text = " ViewportsEnable"))
            }
            if (io.MouseDrawCursor) {
                text(ABOUT_TEXT_19, (text = "io.MouseDrawCursor"))
            }
            if (io.ConfigViewportsNoAutoMerge) {
                text(ABOUT_TEXT_20, (text = "io.ConfigViewportsNoAutoMerge"))
            }
            if (io.ConfigViewportsNoTaskBarIcon) {
                text(ABOUT_TEXT_21, (text = "io.ConfigViewportsNoTaskBarIcon"))
            }
            if (io.ConfigDockingNoSplit) {
                text(ABOUT_TEXT_22, (text = "io.ConfigDockingNoSplit"))
            }
            if (io.ConfigDockingWithShift) {
                text(ABOUT_TEXT_23, (text = "io.ConfigDockingWithShift"))
            }
            if (io.ConfigDockingAlwaysTabBar) {
                text(ABOUT_TEXT_24, (text = "io.ConfigDockingAlwaysTabBar"))
            }
            if (io.ConfigMacOSXBehaviors) {
                text(ABOUT_TEXT_25, (text = "io.ConfigMacOSXBehaviors"))
            }
            if (io.ConfigInputTextCursorBlink) {
                text(ABOUT_TEXT_26, (text = "io.ConfigInputTextCursorBlink"))
            }
            text(ABOUT_TEXT_27, (text = "io.BackendFlags: {fmt_hex(uint(io.BackendFlags))}"))
            if (uint(io.BackendFlags & ImGuiBackendFlags.HasGamepad) != 0u) {
                text(ABOUT_TEXT_28, (text = " HasGamepad"))
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.HasMouseCursors) != 0u) {
                text(ABOUT_TEXT_29, (text = " HasMouseCursors"))
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.HasSetMousePos) != 0u) {
                text(ABOUT_TEXT_30, (text = " HasSetMousePos"))
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.PlatformHasViewports) != 0u) {
                text(ABOUT_TEXT_31, (text = " PlatformHasViewports"))
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.RendererHasVtxOffset) != 0u) {
                text(ABOUT_TEXT_32, (text = " RendererHasVtxOffset"))
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.RendererHasViewports) != 0u) {
                text(ABOUT_TEXT_33, (text = " RendererHasViewports"))
            }
            separator(ABOUT_SEP_4)
            text(ABOUT_TEXT_34, (text = "io.DisplaySize: {io.DisplaySize.x},{io.DisplaySize.y}"))
            text(ABOUT_TEXT_35, (text = "io.DisplayFramebufferScale: {io.DisplayFramebufferScale.x},{io.DisplayFramebufferScale.y}"))
            separator(ABOUT_SEP_5)
            text(ABOUT_TEXT_36, (text = "style.WindowPadding: {style.WindowPadding.x},{style.WindowPadding.y}"))
            text(ABOUT_TEXT_37, (text = "style.WindowBorderSize: {style.WindowBorderSize}"))
            text(ABOUT_TEXT_38, (text = "style.FramePadding: {style.FramePadding.x},{style.FramePadding.y}"))
            text(ABOUT_TEXT_39, (text = "style.FrameRounding: {style.FrameRounding}"))
            text(ABOUT_TEXT_40, (text = "style.FrameBorderSize: {style.FrameBorderSize}"))
            text(ABOUT_TEXT_41, (text = "style.ItemSpacing: {style.ItemSpacing.x},{style.ItemSpacing.y}"))
            text(ABOUT_TEXT_42, (text = "style.ItemInnerSpacing: {style.ItemInnerSpacing.x},{style.ItemInnerSpacing.y}"))

            if (copy_to_clipboard) {
                LogText("\n```\n")
                LogFinish()
            }
            EndChild()
        }
    }
}

def private fmt_hex(v : uint) : string {
    return "0x{v}"
}
