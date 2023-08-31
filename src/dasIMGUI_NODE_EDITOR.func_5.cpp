// this file is generated via daScript automatic C++ binder
// all user modifications will be lost after this file is re-generated

#include "daScript/misc/platform.h"
#include "daScript/ast/ast.h"
#include "daScript/ast/ast_interop.h"
#include "daScript/ast/ast_handle.h"
#include "daScript/ast/ast_typefactory_bind.h"
#include "daScript/simulate/bind_enum.h"
#include "dasIMGUI_NODE_EDITOR.h"
#include "need_dasIMGUI_NODE_EDITOR.h"
namespace das {
#include "dasIMGUI_NODE_EDITOR.func.aot.decl.inc"
void Module_dasIMGUI_NODE_EDITOR::initFunctions_5() {
	makeExtern< bool (*)() , ax::NodeEditor::AcceptCut , SimNode_ExtFuncCall >(lib,"AcceptCut","ax::NodeEditor::AcceptCut")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , ax::NodeEditor::AcceptCopy , SimNode_ExtFuncCall >(lib,"AcceptCopy","ax::NodeEditor::AcceptCopy")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , ax::NodeEditor::AcceptPaste , SimNode_ExtFuncCall >(lib,"AcceptPaste","ax::NodeEditor::AcceptPaste")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , ax::NodeEditor::AcceptDuplicate , SimNode_ExtFuncCall >(lib,"AcceptDuplicate","ax::NodeEditor::AcceptDuplicate")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , ax::NodeEditor::AcceptCreateNode , SimNode_ExtFuncCall >(lib,"AcceptCreateNode","ax::NodeEditor::AcceptCreateNode")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< int (*)() , ax::NodeEditor::GetActionContextSize , SimNode_ExtFuncCall >(lib,"GetActionContextSize","ax::NodeEditor::GetActionContextSize")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< int (*)(ax::NodeEditor::NodeId *,int) , ax::NodeEditor::GetActionContextNodes , SimNode_ExtFuncCall >(lib,"GetActionContextNodes","ax::NodeEditor::GetActionContextNodes")
		->args({"nodes","size"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< int (*)(ax::NodeEditor::LinkId *,int) , ax::NodeEditor::GetActionContextLinks , SimNode_ExtFuncCall >(lib,"GetActionContextLinks","ax::NodeEditor::GetActionContextLinks")
		->args({"links","size"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , ax::NodeEditor::EndShortcut , SimNode_ExtFuncCall >(lib,"EndShortcut","ax::NodeEditor::EndShortcut")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< float (*)() , ax::NodeEditor::GetCurrentZoom , SimNode_ExtFuncCall >(lib,"GetCurrentZoom","ax::NodeEditor::GetCurrentZoom")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ax::NodeEditor::NodeId (*)() , ax::NodeEditor::GetDoubleClickedNode , SimNode_ExtFuncCallAndCopyOrMove >(lib,"GetDoubleClickedNode","ax::NodeEditor::GetDoubleClickedNode")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ax::NodeEditor::PinId (*)() , ax::NodeEditor::GetDoubleClickedPin , SimNode_ExtFuncCallAndCopyOrMove >(lib,"GetDoubleClickedPin","ax::NodeEditor::GetDoubleClickedPin")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ax::NodeEditor::LinkId (*)() , ax::NodeEditor::GetDoubleClickedLink , SimNode_ExtFuncCallAndCopyOrMove >(lib,"GetDoubleClickedLink","ax::NodeEditor::GetDoubleClickedLink")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , ax::NodeEditor::IsBackgroundClicked , SimNode_ExtFuncCall >(lib,"IsBackgroundClicked","ax::NodeEditor::IsBackgroundClicked")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)() , ax::NodeEditor::IsBackgroundDoubleClicked , SimNode_ExtFuncCall >(lib,"IsBackgroundDoubleClicked","ax::NodeEditor::IsBackgroundDoubleClicked")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(ax::NodeEditor::PinId) , ax::NodeEditor::PinHadAnyLinks , SimNode_ExtFuncCall >(lib,"PinHadAnyLinks","ax::NodeEditor::PinHadAnyLinks")
		->args({"pinId"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)() , ax::NodeEditor::GetScreenSize , SimNode_ExtFuncCallAndCopyOrMove >(lib,"GetScreenSize","ax::NodeEditor::GetScreenSize")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)(const ImVec2 &) , ax::NodeEditor::ScreenToCanvas , SimNode_ExtFuncCallAndCopyOrMove >(lib,"ScreenToCanvas","ax::NodeEditor::ScreenToCanvas")
		->args({"pos"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)(const ImVec2 &) , ax::NodeEditor::CanvasToScreen , SimNode_ExtFuncCallAndCopyOrMove >(lib,"CanvasToScreen","ax::NodeEditor::CanvasToScreen")
		->args({"pos"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

