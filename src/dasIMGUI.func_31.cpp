// this file is generated via Daslang automatic binder
// all user modifications will be lost after this file is re-generated

#include "daScript/misc/platform.h"
#include "daScript/ast/ast.h"
#include "daScript/ast/ast_interop.h"
#include "daScript/ast/ast_handle.h"
#include "daScript/ast/ast_typefactory_bind.h"
#include "daScript/simulate/bind_enum.h"
#include "dasIMGUI.h"
#include "need_dasIMGUI.h"
namespace das {
#include "dasIMGUI.func.aot.decl.inc"
void Module_dasIMGUI::initFunctions_31() {
// from imgui_internal.h:3808:29
	makeExtern< void (*)(ImDrawList *,int,int,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,bool) , ImGui::ShadeVertsLinearUV , SimNode_ExtFuncCall , imguiTempFn>(lib,"ShadeVertsLinearUV","ImGui::ShadeVertsLinearUV")
		->args({"draw_list","vert_start_idx","vert_end_idx","a","b","uv_a","uv_b","clamp"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3809:29
	makeExtern< void (*)(ImDrawList *,int,int,const ImVec2 &,float,float,const ImVec2 &) , ImGui::ShadeVertsTransformPos , SimNode_ExtFuncCall , imguiTempFn>(lib,"ShadeVertsTransformPos","ImGui::ShadeVertsTransformPos")
		->args({"draw_list","vert_start_idx","vert_end_idx","pivot_in","cos_a","sin_a","pivot_out"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

