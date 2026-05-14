options gen2
options indenting = 4

module about

require imgui
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
        Text("Dear ImGui {IMGUI_VERSION} ({IMGUI_VERSION_NUM})")
        Separator()
        Text("By Omar Cornut and all Dear ImGui contributors.")
        Text("Dear ImGui is licensed under the MIT License, " +
             "see LICENSE for more information.")
        Text("If your company uses this, please consider funding the project.")

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

            Text("Dear ImGui {IMGUI_VERSION} ({IMGUI_VERSION_NUM})")
            Separator()
            Text("define: __cplusplus elided (daslang port)")
            Text("(C++ build-define block elided; see imgui_demo.cpp:6494-6565)")
            Separator()
            Text("io.BackendPlatformName: {io.BackendPlatformName}")
            Text("io.BackendRendererName: {io.BackendRendererName}")
            Text("io.ConfigFlags: {fmt_hex(uint(io.ConfigFlags))}")
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavEnableKeyboard) != 0u) {
                Text(" NavEnableKeyboard")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavEnableGamepad) != 0u) {
                Text(" NavEnableGamepad")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavEnableSetMousePos) != 0u) {
                Text(" NavEnableSetMousePos")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NavNoCaptureKeyboard) != 0u) {
                Text(" NavNoCaptureKeyboard")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NoMouse) != 0u) {
                Text(" NoMouse")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.NoMouseCursorChange) != 0u) {
                Text(" NoMouseCursorChange")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.DockingEnable) != 0u) {
                Text(" DockingEnable")
            }
            if (uint(io.ConfigFlags & ImGuiConfigFlags.ViewportsEnable) != 0u) {
                Text(" ViewportsEnable")
            }
            if (io.MouseDrawCursor) Text("io.MouseDrawCursor")
            if (io.ConfigViewportsNoAutoMerge) Text("io.ConfigViewportsNoAutoMerge")
            if (io.ConfigViewportsNoTaskBarIcon) Text("io.ConfigViewportsNoTaskBarIcon")
            if (io.ConfigDockingNoSplit) Text("io.ConfigDockingNoSplit")
            if (io.ConfigDockingWithShift) Text("io.ConfigDockingWithShift")
            if (io.ConfigDockingAlwaysTabBar) Text("io.ConfigDockingAlwaysTabBar")
            if (io.ConfigMacOSXBehaviors) Text("io.ConfigMacOSXBehaviors")
            if (io.ConfigInputTextCursorBlink) Text("io.ConfigInputTextCursorBlink")
            Text("io.BackendFlags: {fmt_hex(uint(io.BackendFlags))}")
            if (uint(io.BackendFlags & ImGuiBackendFlags.HasGamepad) != 0u) {
                Text(" HasGamepad")
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.HasMouseCursors) != 0u) {
                Text(" HasMouseCursors")
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.HasSetMousePos) != 0u) {
                Text(" HasSetMousePos")
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.PlatformHasViewports) != 0u) {
                Text(" PlatformHasViewports")
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.RendererHasVtxOffset) != 0u) {
                Text(" RendererHasVtxOffset")
            }
            if (uint(io.BackendFlags & ImGuiBackendFlags.RendererHasViewports) != 0u) {
                Text(" RendererHasViewports")
            }
            Separator()
            Text("io.DisplaySize: {io.DisplaySize.x},{io.DisplaySize.y}")
            Text("io.DisplayFramebufferScale: {io.DisplayFramebufferScale.x},{io.DisplayFramebufferScale.y}")
            Separator()
            Text("style.WindowPadding: {style.WindowPadding.x},{style.WindowPadding.y}")
            Text("style.WindowBorderSize: {style.WindowBorderSize}")
            Text("style.FramePadding: {style.FramePadding.x},{style.FramePadding.y}")
            Text("style.FrameRounding: {style.FrameRounding}")
            Text("style.FrameBorderSize: {style.FrameBorderSize}")
            Text("style.ItemSpacing: {style.ItemSpacing.x},{style.ItemSpacing.y}")
            Text("style.ItemInnerSpacing: {style.ItemInnerSpacing.x},{style.ItemInnerSpacing.y}")

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
