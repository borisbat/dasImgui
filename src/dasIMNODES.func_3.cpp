// this file is generated via daScript automatic C++ binder
// all user modifications will be lost after this file is re-generated

#include "daScript/misc/platform.h"
#include "daScript/ast/ast.h"
#include "daScript/ast/ast_interop.h"
#include "daScript/ast/ast_handle.h"
#include "daScript/ast/ast_typefactory_bind.h"
#include "daScript/simulate/bind_enum.h"
#include "dasIMNODES.h"
#include "need_dasIMNODES.h"
namespace das {
#include "dasIMNODES.func.aot.decl.inc"
void Module_dasIMNODES::initFunctions_3() {
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:309:6
	makeExtern< void (*)(int,int,int) , ImNodes::Link , SimNode_ExtFuncCall, imguiTempFn >(lib,"Link","ImNodes::Link")
		->args({"id","start_attribute_id","end_attribute_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:312:6
	makeExtern< void (*)(int,const bool) , ImNodes::SetNodeDraggable , SimNode_ExtFuncCall, imguiTempFn >(lib,"SetNodeDraggable","ImNodes::SetNodeDraggable")
		->args({"node_id","draggable"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:323:6
	makeExtern< void (*)(int,const ImVec2 &) , ImNodes::SetNodeScreenSpacePos , SimNode_ExtFuncCall , imguiTempFn >(lib,"SetNodeScreenSpacePos","ImNodes::SetNodeScreenSpacePos")
		->args({"node_id","screen_space_pos"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:324:6
	makeExtern< void (*)(int,const ImVec2 &) , ImNodes::SetNodeEditorSpacePos , SimNode_ExtFuncCall , imguiTempFn >(lib,"SetNodeEditorSpacePos","ImNodes::SetNodeEditorSpacePos")
		->args({"node_id","editor_space_pos"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:325:6
	makeExtern< void (*)(int,const ImVec2 &) , ImNodes::SetNodeGridSpacePos , SimNode_ExtFuncCall , imguiTempFn >(lib,"SetNodeGridSpacePos","ImNodes::SetNodeGridSpacePos")
		->args({"node_id","grid_pos"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:327:8
	makeExtern< ImVec2 (*)(const int) , ImNodes::GetNodeScreenSpacePos , SimNode_ExtFuncCall , imguiTempFn >(lib,"GetNodeScreenSpacePos","ImNodes::GetNodeScreenSpacePos")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:328:8
	makeExtern< ImVec2 (*)(const int) , ImNodes::GetNodeEditorSpacePos , SimNode_ExtFuncCall , imguiTempFn >(lib,"GetNodeEditorSpacePos","ImNodes::GetNodeEditorSpacePos")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:329:8
	makeExtern< ImVec2 (*)(const int) , ImNodes::GetNodeGridSpacePos , SimNode_ExtFuncCall , imguiTempFn >(lib,"GetNodeGridSpacePos","ImNodes::GetNodeGridSpacePos")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:333:6
	makeExtern< bool (*)() , ImNodes::IsEditorHovered , SimNode_ExtFuncCall , imguiTempFn >(lib,"IsEditorHovered","ImNodes::IsEditorHovered")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:337:6
	makeExtern< bool (*)(int *) , ImNodes::IsNodeHovered , SimNode_ExtFuncCall , imguiTempFn >(lib,"IsNodeHovered","ImNodes::IsNodeHovered")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:338:6
	makeExtern< bool (*)(int *) , ImNodes::IsLinkHovered , SimNode_ExtFuncCall , imguiTempFn >(lib,"IsLinkHovered","ImNodes::IsLinkHovered")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:339:6
	makeExtern< bool (*)(int *) , ImNodes::IsPinHovered , SimNode_ExtFuncCall , imguiTempFn >(lib,"IsPinHovered","ImNodes::IsPinHovered")
		->args({"attribute_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:343:5
	makeExtern< int (*)() , ImNodes::NumSelectedNodes , SimNode_ExtFuncCall , imguiTempFn >(lib,"NumSelectedNodes","ImNodes::NumSelectedNodes")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:344:5
	makeExtern< int (*)() , ImNodes::NumSelectedLinks , SimNode_ExtFuncCall, imguiTempFn >(lib,"NumSelectedLinks","ImNodes::NumSelectedLinks")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:348:6
	makeExtern< void (*)(int *) , ImNodes::GetSelectedNodes , SimNode_ExtFuncCall, imguiTempFn >(lib,"GetSelectedNodes","ImNodes::GetSelectedNodes")
		->args({"node_ids"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:349:6
	makeExtern< void (*)(int *) , ImNodes::GetSelectedLinks , SimNode_ExtFuncCall, imguiTempFn >(lib,"GetSelectedLinks","ImNodes::GetSelectedLinks")
		->args({"link_ids"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:351:6
	makeExtern< void (*)() , ImNodes::ClearNodeSelection , SimNode_ExtFuncCall, imguiTempFn >(lib,"ClearNodeSelection","ImNodes::ClearNodeSelection")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:352:6
	makeExtern< void (*)() , ImNodes::ClearLinkSelection , SimNode_ExtFuncCall, imguiTempFn >(lib,"ClearLinkSelection","ImNodes::ClearLinkSelection")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:359:6
	makeExtern< void (*)(int) , ImNodes::SelectNode , SimNode_ExtFuncCall, imguiTempFn >(lib,"SelectNode","ImNodes::SelectNode")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:360:6
	makeExtern< void (*)(int) , ImNodes::ClearNodeSelection , SimNode_ExtFuncCall, imguiTempFn >(lib,"ClearNodeSelection","ImNodes::ClearNodeSelection")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

