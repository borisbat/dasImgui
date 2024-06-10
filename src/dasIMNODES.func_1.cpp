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
	addCtorAndUsing<ImNodesIO::EmulateThreeButtonMouseStruct>(*this,lib,"EmulateThreeButtonMouseStruct","ImNodesIO::EmulateThreeButtonMouseStruct");
	addCtorAndUsing<ImNodesIO::LinkDetachWithModifierClickStruct>(*this,lib,"LinkDetachWithModifierClickStruct","ImNodesIO::LinkDetachWithModifierClickStruct");
	addCtorAndUsing<ImNodesIO>(*this,lib,"ImNodesIO","ImNodesIO");
	addCtorAndUsing<ImNodesStyle>(*this,lib,"ImNodesStyle","ImNodesStyle");
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:226:6
	makeExtern< void (*)(ImGuiContext *) , ImNodes::SetImGuiContext , SimNode_ExtFuncCall >(lib,"SetImGuiContext","ImNodes::SetImGuiContext")
		->args({"ctx"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:228:17
	makeExtern< ImNodesContext * (*)() , ImNodes::CreateContext , SimNode_ExtFuncCall >(lib,"CreateContext","ImNodes::CreateContext")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:229:17
	makeExtern< void (*)(ImNodesContext *) , ImNodes::DestroyContext , SimNode_ExtFuncCall >(lib,"DestroyContext","ImNodes::DestroyContext")
		->args({"ctx"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:230:17
	makeExtern< ImNodesContext * (*)() , ImNodes::GetCurrentContext , SimNode_ExtFuncCall >(lib,"GetCurrentContext","ImNodes::GetCurrentContext")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:231:17
	makeExtern< void (*)(ImNodesContext *) , ImNodes::SetCurrentContext , SimNode_ExtFuncCall >(lib,"SetCurrentContext","ImNodes::SetCurrentContext")
		->args({"ctx"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:233:23
	makeExtern< ImNodesEditorContext * (*)() , ImNodes::EditorContextCreate , SimNode_ExtFuncCall >(lib,"EditorContextCreate","ImNodes::EditorContextCreate")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:234:23
	makeExtern< void (*)(ImNodesEditorContext *) , ImNodes::EditorContextFree , SimNode_ExtFuncCall >(lib,"EditorContextFree","ImNodes::EditorContextFree")
		->args({""})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:235:23
	makeExtern< void (*)(ImNodesEditorContext *) , ImNodes::EditorContextSet , SimNode_ExtFuncCall >(lib,"EditorContextSet","ImNodes::EditorContextSet")
		->args({""})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:236:23
	makeExtern< ImVec2 (*)() , ImNodes::EditorContextGetPanning , SimNode_ExtFuncCall >(lib,"EditorContextGetPanning","ImNodes::EditorContextGetPanning")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:237:23
	makeExtern< void (*)(const ImVec2 &) , ImNodes::EditorContextResetPanning , SimNode_ExtFuncCall >(lib,"EditorContextResetPanning","ImNodes::EditorContextResetPanning")
		->args({"pos"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:238:23
	makeExtern< void (*)(const int) , ImNodes::EditorContextMoveToNode , SimNode_ExtFuncCall >(lib,"EditorContextMoveToNode","ImNodes::EditorContextMoveToNode")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:240:12
	makeExtern< ImNodesIO & (*)() , ImNodes::GetIO , SimNode_ExtFuncCallRef >(lib,"GetIO","ImNodes::GetIO")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:243:15
	makeExtern< ImNodesStyle & (*)() , ImNodes::GetStyle , SimNode_ExtFuncCallRef >(lib,"GetStyle","ImNodes::GetStyle")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:245:6
	makeExtern< void (*)() , ImNodes::StyleColorsDark , SimNode_ExtFuncCall >(lib,"StyleColorsDark","ImNodes::StyleColorsDark")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:246:6
	makeExtern< void (*)() , ImNodes::StyleColorsClassic , SimNode_ExtFuncCall >(lib,"StyleColorsClassic","ImNodes::StyleColorsClassic")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:247:6
	makeExtern< void (*)() , ImNodes::StyleColorsLight , SimNode_ExtFuncCall >(lib,"StyleColorsLight","ImNodes::StyleColorsLight")
		->addToModule(*this, SideEffects::worstDefault);
}
}

