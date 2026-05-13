#include "daScript/daScript.h"

#include "imgui_stub.h"
#include <GL/gl3w.h>
#include <GLFW/glfw3.h>

#include "../imgui/backends/imgui_impl_opengl3.h"
#include "../imgui/backends/imgui_impl_glfw.h"

using namespace das;

#define USE_GENERATED 1

#if USE_GENERATED

// NOTE: this module requires GLFW module
#include "need_dasGLFW.h"
IMPLEMENT_EXTERNAL_TYPE_FACTORY(GLFWwindow,GLFWwindow)

MAKE_EXTERNAL_TYPE_FACTORY(ImDrawData,ImDrawData);

#endif

DAS_MOD_API void glfw_error_callback(int error, const char* description) {
    printf("Glfw Error %d: %s\n", error, description);
}

DAS_MOD_API void das_ImGui_ImplOpenGL3_Init ( const char * version ) {
    gl3wInit();
    ImGui_ImplOpenGL3_Init(version);
}

// =====================================================================
// Synthetic IO bypass — direct injection into ImGui's input queue,
// skipping the GLFW backend chain. Used by imgui_live's synth driver to
// fix the click-then-Ctrl+A shortcut-routing bug (project memory:
// project_imgui_synth_click_breaks_ctrl_shortcuts). The driver appends
// synth events AFTER the backend's per-frame poll so synth wins the
// last-write-wins race at NewFrame drain time.
// =====================================================================

DAS_MOD_API void das_imgui_synth_mouse_pos ( float x, float y ) {
    ImGui::GetIO().AddMousePosEvent(x, y);
}

DAS_MOD_API void das_imgui_synth_mouse_button ( int button, bool down ) {
    ImGui::GetIO().AddMouseButtonEvent(button, down);
}

DAS_MOD_API void das_imgui_synth_mouse_wheel ( float dx, float dy ) {
    ImGui::GetIO().AddMouseWheelEvent(dx, dy);
}

DAS_MOD_API void das_imgui_synth_key ( int key, bool down ) {
    ImGui::GetIO().AddKeyEvent((ImGuiKey)key, down);
}

DAS_MOD_API void das_imgui_synth_input_char ( uint32_t cp ) {
    ImGui::GetIO().AddInputCharacter(cp);
}

// making custom builtin module
class Module_imgui_app : public Module {
    ModuleLibrary lib;
public:
    Module_imgui_app() : Module("imgui_app") {
    }
    bool initialized = false;
    virtual bool initDependencies() override {
        if ( initialized ) return true;
        // GLFW
        auto mod_glfw = Module::require("glfw");
        if ( !mod_glfw ) return false;
        if ( !mod_glfw->initDependencies() ) return false;
        // IMGUI
        auto mod_imgui = Module::require("imgui");
        if ( !mod_imgui ) return false;
        if ( !mod_imgui->initDependencies() ) return false;
        // time to initialize
        initialized = true;
        // error callback
        glfwSetErrorCallback(glfw_error_callback);
        // make basic module
        lib.addModule(this);
        lib.addBuiltInModule();
        lib.addModule(mod_glfw);
        lib.addModule(mod_imgui);
#if USE_GENERATED
        // GLFW
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_InitForOpenGL)>(*this,lib,"ImGui_ImplGlfw_InitForOpenGL",
            SideEffects::worstDefault, "ImGui_ImplGlfw_InitForOpenGL");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_InitForVulkan)>(*this,lib,"ImGui_ImplGlfw_InitForVulkan",
            SideEffects::worstDefault, "ImGui_ImplGlfw_InitForVulkan");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_InitForOther)>(*this,lib,"ImGui_ImplGlfw_InitForOther",
            SideEffects::worstDefault, "ImGui_ImplGlfw_InitForOther");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_Shutdown)>(*this,lib,"ImGui_ImplGlfw_Shutdown",
            SideEffects::worstDefault, "ImGui_ImplGlfw_Shutdown");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_NewFrame)>(*this,lib,"ImGui_ImplGlfw_NewFrame",
            SideEffects::worstDefault, "ImGui_ImplGlfw_NewFrame");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_MouseButtonCallback)>(*this,lib,"ImGui_ImplGlfw_MouseButtonCallback",
            SideEffects::worstDefault, "ImGui_ImplGlfw_MouseButtonCallback");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_ScrollCallback)>(*this,lib,"ImGui_ImplGlfw_ScrollCallback",
            SideEffects::worstDefault, "ImGui_ImplGlfw_ScrollCallback");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_KeyCallback)>(*this,lib,"ImGui_ImplGlfw_KeyCallback",
            SideEffects::worstDefault, "ImGui_ImplGlfw_KeyCallback");
        addExtern<DAS_BIND_FUN(ImGui_ImplGlfw_CharCallback)>(*this,lib,"ImGui_ImplGlfw_CharCallback",
            SideEffects::worstDefault, "ImGui_ImplGlfw_CharCallback");
        // OpenGL
        addExtern<DAS_BIND_FUN(das_ImGui_ImplOpenGL3_Init)>(*this,lib,"ImGui_ImplOpenGL3_Init",
            SideEffects::worstDefault, "das_ImGui_ImplOpenGL3_Init");
        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_Shutdown)>(*this,lib,"ImGui_ImplOpenGL3_Shutdown",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_Shutdown");
        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_NewFrame)>(*this,lib,"ImGui_ImplOpenGL3_NewFrame",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_NewFrame");
        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_RenderDrawData)>(*this,lib,"ImGui_ImplOpenGL3_RenderDrawData",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_RenderDrawData");

        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_CreateFontsTexture)>(*this,lib,"ImGui_ImplOpenGL3_CreateFontsTexture",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_CreateFontsTexture");
        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_DestroyFontsTexture)>(*this,lib,"ImGui_ImplOpenGL3_DestroyFontsTexture",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_DestroyFontsTexture");
        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_CreateDeviceObjects)>(*this,lib,"ImGui_ImplOpenGL3_CreateDeviceObjects",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_CreateDeviceObjects");
        addExtern<DAS_BIND_FUN(ImGui_ImplOpenGL3_DestroyDeviceObjects)>(*this,lib,"ImGui_ImplOpenGL3_DestroyDeviceObjects",
            SideEffects::worstDefault, "ImGui_ImplOpenGL3_DestroyDeviceObjects");
#endif
        // Synth IO bypass (imgui_live driver).
        addExtern<DAS_BIND_FUN(das_imgui_synth_mouse_pos)>(*this,lib,"imgui_synth_mouse_pos",
            SideEffects::worstDefault, "das_imgui_synth_mouse_pos");
        addExtern<DAS_BIND_FUN(das_imgui_synth_mouse_button)>(*this,lib,"imgui_synth_mouse_button",
            SideEffects::worstDefault, "das_imgui_synth_mouse_button");
        addExtern<DAS_BIND_FUN(das_imgui_synth_mouse_wheel)>(*this,lib,"imgui_synth_mouse_wheel",
            SideEffects::worstDefault, "das_imgui_synth_mouse_wheel");
        addExtern<DAS_BIND_FUN(das_imgui_synth_key)>(*this,lib,"imgui_synth_key",
            SideEffects::worstDefault, "das_imgui_synth_key");
        addExtern<DAS_BIND_FUN(das_imgui_synth_input_char)>(*this,lib,"imgui_synth_input_char",
            SideEffects::worstDefault, "das_imgui_synth_input_char");
        // all good
        return true;
    }
    virtual ModuleAotType aotRequire ( TextWriter & tw ) const override {
        tw << "#include \"../modules/dasImgui/src/imgui_stub.h\"\n";
        tw << "#include <backends/imgui_impl_glfw.h>\n";
        tw << "#include <backends/imgui_impl_opengl3.h>\n";
        tw << "DAS_MOD_API void das_ImGui_ImplOpenGL3_Init ( const char * version );\n";
        tw << "DAS_MOD_API void das_imgui_synth_mouse_pos ( float x, float y );\n";
        tw << "DAS_MOD_API void das_imgui_synth_mouse_button ( int button, bool down );\n";
        tw << "DAS_MOD_API void das_imgui_synth_mouse_wheel ( float dx, float dy );\n";
        tw << "DAS_MOD_API void das_imgui_synth_key ( int key, bool down );\n";
        tw << "DAS_MOD_API void das_imgui_synth_input_char ( uint32_t cp );\n";
        return ModuleAotType::cpp;
    }
};

REGISTER_DYN_MODULE(Module_imgui_app, Module_imgui_app);

// registering module, so that its available via 'NEED_MODULE' macro
REGISTER_MODULE(Module_imgui_app);

