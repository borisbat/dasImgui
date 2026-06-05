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
// from imgui_internal.h:3725:29
	makeExtern< void (*)(ImVec2,ImVec2,float) , ImGui::RenderFrameBorder , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderFrameBorder","ImGui::RenderFrameBorder")
		->args({"p_min","p_max","rounding"})
		->arg_init(2,new ExprConstFloat(0))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3726:29
	makeExtern< void (*)(ImDrawList *,ImVec2,ImVec2,unsigned int,float,ImVec2,float,int) , ImGui::RenderColorRectWithAlphaCheckerboard , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderColorRectWithAlphaCheckerboard","ImGui::RenderColorRectWithAlphaCheckerboard")
		->args({"draw_list","p_min","p_max","fill_col","grid_step","grid_off","rounding","flags"})
		->arg_init(6,new ExprConstFloat(0))
		->arg_type(7,makeType<ImDrawFlags_>(lib))
		->arg_init(7,new ExprConstEnumeration(0,makeType<ImDrawFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3727:29
	makeExtern< void (*)(const ImRect &,unsigned int,int) , ImGui::RenderNavHighlight , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderNavHighlight","ImGui::RenderNavHighlight")
		->args({"bb","id","flags"})
		->arg_init(2,new ExprConstInt(0))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3729:29
	makeExtern< void (*)(ImVec2,float,int,unsigned int,unsigned int,unsigned int) , ImGui::RenderMouseCursor , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderMouseCursor","ImGui::RenderMouseCursor")
		->args({"pos","scale","mouse_cursor","col_fill","col_border","col_shadow"})
		->arg_type(2,makeType<ImGuiMouseCursor_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3732:29
	makeExtern< void (*)(ImDrawList *,ImVec2,unsigned int,int,float) , ImGui::RenderArrow , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderArrow","ImGui::RenderArrow")
		->args({"draw_list","pos","col","dir","scale"})
		->arg_type(3,makeType<ImGuiDir_>(lib))
		->arg_init(4,new ExprConstFloat(1))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3733:29
	makeExtern< void (*)(ImDrawList *,ImVec2,unsigned int) , ImGui::RenderBullet , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderBullet","ImGui::RenderBullet")
		->args({"draw_list","pos","col"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3734:29
	makeExtern< void (*)(ImDrawList *,ImVec2,unsigned int,float) , ImGui::RenderCheckMark , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderCheckMark","ImGui::RenderCheckMark")
		->args({"draw_list","pos","col","sz"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3735:29
	makeExtern< void (*)(ImDrawList *,ImVec2,ImVec2,int,unsigned int) , ImGui::RenderArrowPointingAt , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderArrowPointingAt","ImGui::RenderArrowPointingAt")
		->args({"draw_list","pos","half_sz","direction","col"})
		->arg_type(3,makeType<ImGuiDir_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3736:29
	makeExtern< void (*)(ImDrawList *,ImVec2,float,unsigned int) , ImGui::RenderArrowDockMenu , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderArrowDockMenu","ImGui::RenderArrowDockMenu")
		->args({"draw_list","p_min","sz","col"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3737:29
	makeExtern< void (*)(ImDrawList *,const ImRect &,unsigned int,float,float,float) , ImGui::RenderRectFilledRangeH , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderRectFilledRangeH","ImGui::RenderRectFilledRangeH")
		->args({"draw_list","rect","col","x_start_norm","x_end_norm","rounding"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3738:29
	makeExtern< void (*)(ImDrawList *,const ImRect &,const ImRect &,unsigned int,float) , ImGui::RenderRectFilledWithHole , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderRectFilledWithHole","ImGui::RenderRectFilledWithHole")
		->args({"draw_list","outer","inner","col","rounding"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3767:29
	makeExtern< void (*)(unsigned int) , ImGui::TreePushOverrideID , SimNode_ExtFuncCall , imguiTempFn>(lib,"TreePushOverrideID","ImGui::TreePushOverrideID")
		->args({"id"})
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

