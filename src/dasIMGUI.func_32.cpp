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
void Module_dasIMGUI::initFunctions_32() {
// from imgui_internal.h:3737:29
	makeExtern< void (*)(ImDrawList *,const ImRect &,unsigned int,float,float,float) , ImGui::RenderRectFilledRangeH , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderRectFilledRangeH","ImGui::RenderRectFilledRangeH")
		->args({"draw_list","rect","col","x_start_norm","x_end_norm","rounding"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3738:29
	makeExtern< void (*)(ImDrawList *,const ImRect &,const ImRect &,unsigned int,float) , ImGui::RenderRectFilledWithHole , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderRectFilledWithHole","ImGui::RenderRectFilledWithHole")
		->args({"draw_list","outer","inner","col","rounding"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3739:29
	makeExtern< int (*)(const ImRect &,const ImRect &,float) , ImGui::CalcRoundingFlagsForRectInRect , SimNode_ExtFuncCall , imguiTempFn>(lib,"CalcRoundingFlagsForRectInRect","ImGui::CalcRoundingFlagsForRectInRect")
		->args({"r_in","r_outer","threshold"})
		->res_type(makeType<ImDrawFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3743:29
	makeExtern< bool (*)(const char *,const ImVec2 &,int) , ImGui::ButtonEx , SimNode_ExtFuncCall , imguiTempFn>(lib,"ButtonEx","ImGui::ButtonEx")
		->args({"label","size_arg","flags"})
		->arg_type(2,makeType<ImGuiButtonFlags_>(lib))
		->arg_init(2,new ExprConstEnumeration(0,makeType<ImGuiButtonFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3744:29
	makeExtern< bool (*)(const char *,int,ImVec2,int) , ImGui::ArrowButtonEx , SimNode_ExtFuncCall , imguiTempFn>(lib,"ArrowButtonEx","ImGui::ArrowButtonEx")
		->args({"str_id","dir","size_arg","flags"})
		->arg_type(1,makeType<ImGuiDir_>(lib))
		->arg_type(3,makeType<ImGuiButtonFlags_>(lib))
		->arg_init(3,new ExprConstEnumeration(0,makeType<ImGuiButtonFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3754:29
	makeExtern< void (*)(ImGuiAxis) , ImGui::Scrollbar , SimNode_ExtFuncCall , imguiTempFn>(lib,"Scrollbar","ImGui::Scrollbar")
		->args({"axis"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3767:29
	makeExtern< void (*)(unsigned int) , ImGui::TreePushOverrideID , SimNode_ExtFuncCall , imguiTempFn>(lib,"TreePushOverrideID","ImGui::TreePushOverrideID")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3768:29
	makeExtern< void (*)(unsigned int,bool) , ImGui::TreeNodeSetOpen , SimNode_ExtFuncCall , imguiTempFn>(lib,"TreeNodeSetOpen","ImGui::TreeNodeSetOpen")
		->args({"id","open"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3769:29
	makeExtern< bool (*)(unsigned int,int) , ImGui::TreeNodeUpdateNextOpen , SimNode_ExtFuncCall , imguiTempFn>(lib,"TreeNodeUpdateNextOpen","ImGui::TreeNodeUpdateNextOpen")
		->args({"id","flags"})
		->arg_type(1,makeType<ImGuiTreeNodeFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3770:29
	makeExtern< void (*)(ImGuiSelectionUserData) , ImGui::SetNextItemSelectionUserData , SimNode_ExtFuncCall , imguiTempFn>(lib,"SetNextItemSelectionUserData","ImGui::SetNextItemSelectionUserData")
		->args({"selection_user_data"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3807:29
	makeExtern< void (*)(ImDrawList *,int,int,ImVec2,ImVec2,unsigned int,unsigned int) , ImGui::ShadeVertsLinearColorGradientKeepAlpha , SimNode_ExtFuncCall , imguiTempFn>(lib,"ShadeVertsLinearColorGradientKeepAlpha","ImGui::ShadeVertsLinearColorGradientKeepAlpha")
		->args({"draw_list","vert_start_idx","vert_end_idx","gradient_p0","gradient_p1","col0","col1"})
		->addToModule(*this, SideEffects::worstDefault);
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

