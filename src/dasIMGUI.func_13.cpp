// this file is generated via daScript automatic C++ binder
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
void Module_dasIMGUI::initFunctions_13() {
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:813:37
	makeExtern< int (*)() , ImGui::TableGetColumnCount , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableGetColumnCount","ImGui::TableGetColumnCount")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:814:37
	makeExtern< int (*)() , ImGui::TableGetColumnIndex , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableGetColumnIndex","ImGui::TableGetColumnIndex")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:815:37
	makeExtern< int (*)() , ImGui::TableGetRowIndex , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableGetRowIndex","ImGui::TableGetRowIndex")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:816:37
	makeExtern< const char * (*)(int) , ImGui::TableGetColumnName , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableGetColumnName","ImGui::TableGetColumnName")
		->args({"column_n"})
		->arg_init(0,make_smart<ExprConstInt>(-1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:817:37
	makeExtern< int (*)(int) , ImGui::TableGetColumnFlags , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableGetColumnFlags","ImGui::TableGetColumnFlags")
		->args({"column_n"})
		->arg_init(0,make_smart<ExprConstInt>(-1))
		->res_type(makeType<ImGuiTableColumnFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:818:37
	makeExtern< void (*)(int,bool) , ImGui::TableSetColumnEnabled , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableSetColumnEnabled","ImGui::TableSetColumnEnabled")
		->args({"column_n","v"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:819:37
	makeExtern< void (*)(int,unsigned int,int) , ImGui::TableSetBgColor , SimNode_ExtFuncCall , imguiTempFn>(lib,"TableSetBgColor","ImGui::TableSetBgColor")
		->args({"target","color","column_n"})
		->arg_type(0,makeType<ImGuiTableBgTarget_>(lib))
		->arg_init(2,make_smart<ExprConstInt>(-1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:823:29
	makeExtern< void (*)(int,const char *,bool) , ImGui::Columns , SimNode_ExtFuncCall , imguiTempFn>(lib,"Columns","ImGui::Columns")
		->args({"count","id","border"})
		->arg_init(0,make_smart<ExprConstInt>(1))
		->arg_init(1,make_smart<ExprConstString>(""))
		->arg_init(2,make_smart<ExprConstBool>(true))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:824:29
	makeExtern< void (*)() , ImGui::NextColumn , SimNode_ExtFuncCall , imguiTempFn>(lib,"NextColumn","ImGui::NextColumn")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:825:29
	makeExtern< int (*)() , ImGui::GetColumnIndex , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetColumnIndex","ImGui::GetColumnIndex")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:826:29
	makeExtern< float (*)(int) , ImGui::GetColumnWidth , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetColumnWidth","ImGui::GetColumnWidth")
		->args({"column_index"})
		->arg_init(0,make_smart<ExprConstInt>(-1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:827:29
	makeExtern< void (*)(int,float) , ImGui::SetColumnWidth , SimNode_ExtFuncCall , imguiTempFn>(lib,"SetColumnWidth","ImGui::SetColumnWidth")
		->args({"column_index","width"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:828:29
	makeExtern< float (*)(int) , ImGui::GetColumnOffset , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetColumnOffset","ImGui::GetColumnOffset")
		->args({"column_index"})
		->arg_init(0,make_smart<ExprConstInt>(-1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:829:29
	makeExtern< void (*)(int,float) , ImGui::SetColumnOffset , SimNode_ExtFuncCall , imguiTempFn>(lib,"SetColumnOffset","ImGui::SetColumnOffset")
		->args({"column_index","offset_x"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:830:29
	makeExtern< int (*)() , ImGui::GetColumnsCount , SimNode_ExtFuncCall , imguiTempFn>(lib,"GetColumnsCount","ImGui::GetColumnsCount")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:834:29
	makeExtern< bool (*)(const char *,int) , ImGui::BeginTabBar , SimNode_ExtFuncCall , imguiTempFn>(lib,"BeginTabBar","ImGui::BeginTabBar")
		->args({"str_id","flags"})
		->arg_type(1,makeType<ImGuiTabBarFlags_>(lib))
		->arg_init(1,make_smart<ExprConstEnumeration>(0,makeType<ImGuiTabBarFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:835:29
	makeExtern< void (*)() , ImGui::EndTabBar , SimNode_ExtFuncCall , imguiTempFn>(lib,"EndTabBar","ImGui::EndTabBar")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:836:29
	makeExtern< bool (*)(const char *,bool *,int) , ImGui::BeginTabItem , SimNode_ExtFuncCall , imguiTempFn>(lib,"BeginTabItem","ImGui::BeginTabItem")
		->args({"label","p_open","flags"})
		->arg_init(1,make_smart<ExprConstPtr>())
		->arg_type(2,makeType<ImGuiTabItemFlags_>(lib))
		->arg_init(2,make_smart<ExprConstEnumeration>(0,makeType<ImGuiTabItemFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:837:29
	makeExtern< void (*)() , ImGui::EndTabItem , SimNode_ExtFuncCall , imguiTempFn>(lib,"EndTabItem","ImGui::EndTabItem")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:838:29
	makeExtern< bool (*)(const char *,int) , ImGui::TabItemButton , SimNode_ExtFuncCall , imguiTempFn>(lib,"TabItemButton","ImGui::TabItemButton")
		->args({"label","flags"})
		->arg_type(1,makeType<ImGuiTabItemFlags_>(lib))
		->arg_init(1,make_smart<ExprConstEnumeration>(0,makeType<ImGuiTabItemFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
}
}

