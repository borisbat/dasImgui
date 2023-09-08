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
	makeExtern< void (*)(int,const bool) , imnodes::SetNodeDraggable , SimNode_ExtFuncCall >(lib,"SetNodeDraggable","imnodes::SetNodeDraggable")
		->args({"node_id","draggable"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int,const ImVec2 &) , imnodes::SetNodeScreenSpacePos , SimNode_ExtFuncCall >(lib,"SetNodeScreenSpacePos","imnodes::SetNodeScreenSpacePos")
		->args({"node_id","screen_space_pos"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int,const ImVec2 &) , imnodes::SetNodeEditorSpacePos , SimNode_ExtFuncCall >(lib,"SetNodeEditorSpacePos","imnodes::SetNodeEditorSpacePos")
		->args({"node_id","editor_space_pos"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int,const ImVec2 &) , imnodes::SetNodeGridSpacePos , SimNode_ExtFuncCall >(lib,"SetNodeGridSpacePos","imnodes::SetNodeGridSpacePos")
		->args({"node_id","grid_pos"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)(const int) , imnodes::GetNodeScreenSpacePos , SimNode_ExtFuncCall >(lib,"GetNodeScreenSpacePos","imnodes::GetNodeScreenSpacePos")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)(const int) , imnodes::GetNodeEditorSpacePos , SimNode_ExtFuncCall >(lib,"GetNodeEditorSpacePos","imnodes::GetNodeEditorSpacePos")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)(const int) , imnodes::GetNodeGridSpacePos , SimNode_ExtFuncCall >(lib,"GetNodeGridSpacePos","imnodes::GetNodeGridSpacePos")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , imnodes::IsEditorHovered , SimNode_ExtFuncCall >(lib,"IsEditorHovered","imnodes::IsEditorHovered")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *) , imnodes::IsNodeHovered , SimNode_ExtFuncCall >(lib,"IsNodeHovered","imnodes::IsNodeHovered")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *) , imnodes::IsLinkHovered , SimNode_ExtFuncCall >(lib,"IsLinkHovered","imnodes::IsLinkHovered")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *) , imnodes::IsPinHovered , SimNode_ExtFuncCall >(lib,"IsPinHovered","imnodes::IsPinHovered")
		->args({"attribute_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< int (*)() , imnodes::NumSelectedNodes , SimNode_ExtFuncCall >(lib,"NumSelectedNodes","imnodes::NumSelectedNodes")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< int (*)() , imnodes::NumSelectedLinks , SimNode_ExtFuncCall >(lib,"NumSelectedLinks","imnodes::NumSelectedLinks")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int *) , imnodes::GetSelectedNodes , SimNode_ExtFuncCall >(lib,"GetSelectedNodes","imnodes::GetSelectedNodes")
		->args({"node_ids"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int *) , imnodes::GetSelectedLinks , SimNode_ExtFuncCall >(lib,"GetSelectedLinks","imnodes::GetSelectedLinks")
		->args({"link_ids"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::ClearNodeSelection , SimNode_ExtFuncCall >(lib,"ClearNodeSelection","imnodes::ClearNodeSelection")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::ClearLinkSelection , SimNode_ExtFuncCall >(lib,"ClearLinkSelection","imnodes::ClearLinkSelection")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , imnodes::IsAttributeActive , SimNode_ExtFuncCall >(lib,"IsAttributeActive","imnodes::IsAttributeActive")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *) , imnodes::IsAnyAttributeActive , SimNode_ExtFuncCall >(lib,"IsAnyAttributeActive","imnodes::IsAnyAttributeActive")
		->args({"attribute_id"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *) , imnodes::IsLinkStarted , SimNode_ExtFuncCall >(lib,"IsLinkStarted","imnodes::IsLinkStarted")
		->args({"started_at_attribute_id"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

