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
void Module_dasIMNODES::initFunctions_1() {
	addCtorAndUsing<imnodes::IO::EmulateThreeButtonMouse>(*this,lib,"EmulateThreeButtonMouse","imnodes::IO::EmulateThreeButtonMouse");
	addCtorAndUsing<imnodes::IO::LinkDetachWithModifierClick>(*this,lib,"LinkDetachWithModifierClick","imnodes::IO::LinkDetachWithModifierClick");
	addCtorAndUsing<imnodes::IO>(*this,lib,"IO","imnodes::IO");
	addCtorAndUsing<imnodes::Style>(*this,lib,"Style","imnodes::Style");
	makeExtern< void (*)(ImGuiContext *) , imnodes::SetImGuiContext , SimNode_ExtFuncCall >(lib,"SetImGuiContext","imnodes::SetImGuiContext")
		->args({"ctx"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< imnodes::Context * (*)() , imnodes::CreateContext , SimNode_ExtFuncCall >(lib,"CreateContext","imnodes::CreateContext")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::Context *) , imnodes::DestroyContext , SimNode_ExtFuncCall >(lib,"DestroyContext","imnodes::DestroyContext")
		->args({"ctx"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< imnodes::Context * (*)() , imnodes::GetCurrentContext , SimNode_ExtFuncCall >(lib,"GetCurrentContext","imnodes::GetCurrentContext")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::Context *) , imnodes::SetCurrentContext , SimNode_ExtFuncCall >(lib,"SetCurrentContext","imnodes::SetCurrentContext")
		->args({"ctx"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< imnodes::EditorContext * (*)() , imnodes::EditorContextCreate , SimNode_ExtFuncCall >(lib,"EditorContextCreate","imnodes::EditorContextCreate")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::EditorContext *) , imnodes::EditorContextFree , SimNode_ExtFuncCall >(lib,"EditorContextFree","imnodes::EditorContextFree")
		->args({""})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::EditorContext *) , imnodes::EditorContextSet , SimNode_ExtFuncCall >(lib,"EditorContextSet","imnodes::EditorContextSet")
		->args({""})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)() , imnodes::EditorContextGetPanning , SimNode_ExtFuncCallAndCopyOrMove >(lib,"EditorContextGetPanning","imnodes::EditorContextGetPanning")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(const ImVec2 &) , imnodes::EditorContextResetPanning , SimNode_ExtFuncCall >(lib,"EditorContextResetPanning","imnodes::EditorContextResetPanning")
		->args({"pos"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(const int) , imnodes::EditorContextMoveToNode , SimNode_ExtFuncCall >(lib,"EditorContextMoveToNode","imnodes::EditorContextMoveToNode")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< imnodes::IO & (*)() , imnodes::GetIO , SimNode_ExtFuncCallRef >(lib,"GetIO","imnodes::GetIO")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< imnodes::Style & (*)() , imnodes::GetStyle , SimNode_ExtFuncCallRef >(lib,"GetStyle","imnodes::GetStyle")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::StyleColorsDark , SimNode_ExtFuncCall >(lib,"StyleColorsDark","imnodes::StyleColorsDark")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::StyleColorsClassic , SimNode_ExtFuncCall >(lib,"StyleColorsClassic","imnodes::StyleColorsClassic")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::StyleColorsLight , SimNode_ExtFuncCall >(lib,"StyleColorsLight","imnodes::StyleColorsLight")
		->addToModule(*this, SideEffects::worstDefault);
}
}

