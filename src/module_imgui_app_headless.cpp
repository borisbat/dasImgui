#include "daScript/daScript.h"

#include "imgui_stub.h"

using namespace das;

// =====================================================================
// imgui_app_headless — display-less ImGui backend.
//
// Companion to imgui_app for CI / Playwright-driven runs where no
// display server (GLFW/OpenGL) is available. Exposes a deliberately
// minimal 3-function surface used by imgui/imgui_harness when its
// --headless arm is active. Does NOT mirror imgui_app's GLFW/GL
// surface — keeping those names absent from headless scope is the
// structural guarantee behind the harness lint (no GLFW/GL symbol can
// resolve in a harness-using file under headless).
//
// Synth IO (das_imgui_synth_*) lives in imgui_app — those functions
// only touch ImGui::GetIO()->AddXxxEvent and have no GLFW/GL deps,
// so they work in both modes; the harness imports both modules.
// =====================================================================

DAS_MOD_API void das_imgui_headless_init_fonts() {
    ImGuiIO & io = ImGui::GetIO();
    if (!io.Fonts->IsBuilt()) {
        io.Fonts->Build();
    }
    // Satisfy ImGui's "is texture present?" assertion paths without an
    // OpenGL backend — any non-zero TexID is acceptable when no draw
    // data is consumed.
    io.Fonts->TexID = (ImTextureID)1;
}

DAS_MOD_API void das_imgui_headless_set_display_size(float w, float h) {
    ImGui::GetIO().DisplaySize = ImVec2(w, h);
}

DAS_MOD_API void das_imgui_headless_advance_dt(float dt) {
    ImGui::GetIO().DeltaTime = dt;
}

class Module_imgui_app_headless : public Module {
    ModuleLibrary lib;
public:
    Module_imgui_app_headless() : Module("imgui_app_headless") {
    }
    bool initialized = false;
    virtual bool initDependencies() override {
        if ( initialized ) return true;
        auto mod_imgui = Module::require("imgui");
        if ( !mod_imgui ) return false;
        if ( !mod_imgui->initDependencies() ) return false;
        initialized = true;
        lib.addModule(this);
        lib.addBuiltInModule();
        lib.addModule(mod_imgui);
        addExtern<DAS_BIND_FUN(das_imgui_headless_init_fonts)>(*this,lib,"imgui_headless_init_fonts",
            SideEffects::worstDefault, "das_imgui_headless_init_fonts");
        addExtern<DAS_BIND_FUN(das_imgui_headless_set_display_size)>(*this,lib,"imgui_headless_set_display_size",
            SideEffects::worstDefault, "das_imgui_headless_set_display_size");
        addExtern<DAS_BIND_FUN(das_imgui_headless_advance_dt)>(*this,lib,"imgui_headless_advance_dt",
            SideEffects::worstDefault, "das_imgui_headless_advance_dt");
        return true;
    }
    virtual ModuleAotType aotRequire ( TextWriter & tw ) const override {
        tw << "#include \"../modules/dasImgui/src/imgui_stub.h\"\n";
        tw << "DAS_MOD_API void das_imgui_headless_init_fonts();\n";
        tw << "DAS_MOD_API void das_imgui_headless_set_display_size(float w, float h);\n";
        tw << "DAS_MOD_API void das_imgui_headless_advance_dt(float dt);\n";
        return ModuleAotType::cpp;
    }
};

REGISTER_DYN_MODULE(Module_imgui_app_headless, Module_imgui_app_headless);
REGISTER_MODULE(Module_imgui_app_headless);
