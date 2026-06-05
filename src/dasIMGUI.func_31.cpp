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
// from imgui_internal.h:3455:29
	makeExtern< void (*)() , ImGui::FocusItem , SimNode_ExtFuncCall , imguiTempFn>(lib,"FocusItem","ImGui::FocusItem")
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3456:29
	makeExtern< void (*)(unsigned int) , ImGui::ActivateItemByID , SimNode_ExtFuncCall , imguiTempFn>(lib,"ActivateItemByID","ImGui::ActivateItemByID")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3608:29
	makeExtern< void (*)(unsigned int) , ImGui::PushFocusScope , SimNode_ExtFuncCall , imguiTempFn>(lib,"PushFocusScope","ImGui::PushFocusScope")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3609:29
	makeExtern< void (*)() , ImGui::PopFocusScope , SimNode_ExtFuncCall , imguiTempFn>(lib,"PopFocusScope","ImGui::PopFocusScope")
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3610:29
	makeExtern< unsigned int (*)() , ImGui::GetCurrentFocusScope , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetCurrentFocusScope","ImGui::GetCurrentFocusScope")
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3617:29
	makeExtern< void (*)(const ImRect &,const ImRect &) , ImGui::RenderDragDropTargetRect , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderDragDropTargetRect","ImGui::RenderDragDropTargetRect")
		->args({"bb","item_clip_rect"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3719:29
	makeExtern< void (*)(ImVec2,const char *,const char *,bool) , ImGui::RenderText , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderText","ImGui::RenderText")
		->args({"pos","text","text_end","hide_text_after_hash"})
		->arg_init(2,new ExprConstString(""))
		->arg_init(3,new ExprConstBool(true))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3720:29
	makeExtern< void (*)(ImVec2,const char *,const char *,float) , ImGui::RenderTextWrapped , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderTextWrapped","ImGui::RenderTextWrapped")
		->args({"pos","text","text_end","wrap_width"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3724:29
	makeExtern< void (*)(ImVec2,ImVec2,unsigned int,bool,float) , ImGui::RenderFrame , SimNode_ExtFuncCall , imguiTempFn>(lib,"RenderFrame","ImGui::RenderFrame")
		->args({"p_min","p_max","fill_col","border","rounding"})
		->arg_init(3,new ExprConstBool(true))
		->arg_init(4,new ExprConstFloat(0))
		->addToModule(*this, SideEffects::worstDefault);
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
}
}

