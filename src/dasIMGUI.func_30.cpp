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
// from imgui_internal.h:3375:29
	makeExtern< void (*)(unsigned int) , ImGui::MarkItemEdited , SimNode_ExtFuncCall , imguiTempFn>(lib,"MarkItemEdited","ImGui::MarkItemEdited")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3376:29
	makeExtern< void (*)(unsigned int) , ImGui::PushOverrideID , SimNode_ExtFuncCall , imguiTempFn>(lib,"PushOverrideID","ImGui::PushOverrideID")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3377:29
	makeExtern< unsigned int (*)(const char *,const char *,unsigned int) , ImGui::GetIDWithSeed , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetIDWithSeed","ImGui::GetIDWithSeed")
		->args({"str_id_begin","str_id_end","seed"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3378:29
	makeExtern< unsigned int (*)(int,unsigned int) , ImGui::GetIDWithSeed , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetIDWithSeed","ImGui::GetIDWithSeed")
		->args({"n","seed"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3381:29
	makeExtern< void (*)(const ImVec2 &,float) , ImGui::ItemSize , SimNode_ExtFuncCall , imguiTempFn>(lib,"ItemSize","ImGui::ItemSize")
		->args({"size","text_baseline_y"})
		->arg_init(1,new ExprConstFloat(-1))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3382:29
	makeExtern< void (*)(const ImRect &,float) , ImGui::ItemSize , SimNode_ExtFuncCall , imguiTempFn>(lib,"ItemSize","ImGui::ItemSize")
		->args({"bb","text_baseline_y"})
		->arg_init(1,new ExprConstFloat(-1))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3384:29
	makeExtern< bool (*)(const ImRect &,unsigned int,int) , ImGui::ItemHoverable , SimNode_ExtFuncCall , imguiTempFn>(lib,"ItemHoverable","ImGui::ItemHoverable")
		->args({"bb","id","item_flags"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3386:29
	makeExtern< bool (*)(const ImRect &,unsigned int) , ImGui::IsClippedEx , SimNode_ExtFuncCall , imguiTempFn>(lib,"IsClippedEx","ImGui::IsClippedEx")
		->args({"bb","id"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3388:29
	makeExtern< ImVec2 (*)(ImVec2,float,float) , ImGui::CalcItemSize , SimNode_ExtFuncCall , imguiTempFn>(lib,"CalcItemSize","ImGui::CalcItemSize")
		->args({"size","default_w","default_h"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3389:29
	makeExtern< float (*)(const ImVec2 &,float) , ImGui::CalcWrapWidthForPos , SimNode_ExtFuncCall , imguiTempFn>(lib,"CalcWrapWidthForPos","ImGui::CalcWrapWidthForPos")
		->args({"pos","wrap_pos_x"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3392:29
	makeExtern< ImVec2 (*)() , ImGui::GetContentRegionMaxAbs , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetContentRegionMaxAbs","ImGui::GetContentRegionMaxAbs")
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3396:29
	makeExtern< void (*)(int,bool) , ImGui::PushItemFlag , SimNode_ExtFuncCall , imguiTempFn>(lib,"PushItemFlag","ImGui::PushItemFlag")
		->args({"option","enabled"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3397:29
	makeExtern< void (*)() , ImGui::PopItemFlag , SimNode_ExtFuncCall , imguiTempFn>(lib,"PopItemFlag","ImGui::PopItemFlag")
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3408:29
	makeExtern< void (*)(unsigned int,int) , ImGui::OpenPopupEx , SimNode_ExtFuncCall , imguiTempFn>(lib,"OpenPopupEx","ImGui::OpenPopupEx")
		->args({"id","popup_flags"})
		->arg_type(1,makeType<ImGuiPopupFlags_>(lib))
		->arg_init(1,new ExprConstEnumeration(0,makeType<ImGuiPopupFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3409:29
	makeExtern< void (*)(int,bool) , ImGui::ClosePopupToLevel , SimNode_ExtFuncCall , imguiTempFn>(lib,"ClosePopupToLevel","ImGui::ClosePopupToLevel")
		->args({"remaining","restore_focus_to_window_under_popup"})
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3411:29
	makeExtern< void (*)() , ImGui::ClosePopupsExceptModals , SimNode_ExtFuncCall , imguiTempFn>(lib,"ClosePopupsExceptModals","ImGui::ClosePopupsExceptModals")
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3412:29
	makeExtern< bool (*)(unsigned int,int) , ImGui::IsPopupOpen , SimNode_ExtFuncCall , imguiTempFn>(lib,"IsPopupOpen","ImGui::IsPopupOpen")
		->args({"id","popup_flags"})
		->arg_type(1,makeType<ImGuiPopupFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3413:29
	makeExtern< bool (*)(unsigned int,int) , ImGui::BeginPopupEx , SimNode_ExtFuncCall , imguiTempFn>(lib,"BeginPopupEx","ImGui::BeginPopupEx")
		->args({"id","extra_flags"})
		->arg_type(1,makeType<ImGuiWindowFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3414:29
	makeExtern< bool (*)(int,int) , ImGui::BeginTooltipEx , SimNode_ExtFuncCall , imguiTempFn>(lib,"BeginTooltipEx","ImGui::BeginTooltipEx")
		->args({"tooltip_flags","extra_window_flags"})
		->arg_type(1,makeType<ImGuiWindowFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from imgui_internal.h:3415:29
	makeExtern< bool (*)() , ImGui::BeginTooltipHidden , SimNode_ExtFuncCall , imguiTempFn>(lib,"BeginTooltipHidden","ImGui::BeginTooltipHidden")
		->addToModule(*this, SideEffects::worstDefault);
}
}

