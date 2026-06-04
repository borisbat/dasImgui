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
void Module_dasIMGUI::initFunctions_30() {
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
}
}

