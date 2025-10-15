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
void Module_dasIMNODES::initFunctions_2() {
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:251:6
	makeExtern< void (*)() , ImNodes::BeginNodeEditor , SimNode_ExtFuncCall, imguiTempFn >(lib,"BeginNodeEditor","ImNodes::BeginNodeEditor")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:252:6
	makeExtern< void (*)() , ImNodes::EndNodeEditor , SimNode_ExtFuncCall, imguiTempFn >(lib,"EndNodeEditor","ImNodes::EndNodeEditor")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:263:6
	makeExtern< void (*)(int,unsigned int) , ImNodes::PushColorStyle , SimNode_ExtFuncCall, imguiTempFn >(lib,"PushColorStyle","ImNodes::PushColorStyle")
		->args({"item","color"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:264:6
	makeExtern< void (*)() , ImNodes::PopColorStyle , SimNode_ExtFuncCall, imguiTempFn >(lib,"PopColorStyle","ImNodes::PopColorStyle")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:265:6
	makeExtern< void (*)(int,float) , ImNodes::PushStyleVar , SimNode_ExtFuncCall, imguiTempFn >(lib,"PushStyleVar","ImNodes::PushStyleVar")
		->args({"style_item","value"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:266:6
	makeExtern< void (*)(int,const ImVec2 &) , ImNodes::PushStyleVar , SimNode_ExtFuncCall, imguiTempFn >(lib,"PushStyleVar","ImNodes::PushStyleVar")
		->args({"style_item","value"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:267:6
	makeExtern< void (*)(int) , ImNodes::PopStyleVar , SimNode_ExtFuncCall, imguiTempFn >(lib,"PopStyleVar","ImNodes::PopStyleVar")
		->args({"count"})
		->arg_init(0,make_smart<ExprConstInt>(1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:270:6
	makeExtern< void (*)(int) , ImNodes::BeginNode , SimNode_ExtFuncCall, imguiTempFn >(lib,"BeginNode","ImNodes::BeginNode")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:271:6
	makeExtern< void (*)() , ImNodes::EndNode , SimNode_ExtFuncCall, imguiTempFn >(lib,"EndNode","ImNodes::EndNode")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:273:8
	makeExtern< ImVec2 (*)(int) , ImNodes::GetNodeDimensions , SimNode_ExtFuncCall, imguiTempFn >(lib,"GetNodeDimensions","ImNodes::GetNodeDimensions")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:278:6
	makeExtern< void (*)() , ImNodes::BeginNodeTitleBar , SimNode_ExtFuncCall, imguiTempFn >(lib,"BeginNodeTitleBar","ImNodes::BeginNodeTitleBar")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:279:6
	makeExtern< void (*)() , ImNodes::EndNodeTitleBar , SimNode_ExtFuncCall, imguiTempFn >(lib,"EndNodeTitleBar","ImNodes::EndNodeTitleBar")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:291:6
	makeExtern< void (*)(int,int) , ImNodes::BeginInputAttribute , SimNode_ExtFuncCall, imguiTempFn >(lib,"BeginInputAttribute","ImNodes::BeginInputAttribute")
		->args({"id","shape"})
		->arg_init(1,make_smart<ExprConstInt>(1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:292:6
	makeExtern< void (*)() , ImNodes::EndInputAttribute , SimNode_ExtFuncCall, imguiTempFn >(lib,"EndInputAttribute","ImNodes::EndInputAttribute")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:294:6
	makeExtern< void (*)(int,int) , ImNodes::BeginOutputAttribute , SimNode_ExtFuncCall, imguiTempFn >(lib,"BeginOutputAttribute","ImNodes::BeginOutputAttribute")
		->args({"id","shape"})
		->arg_init(1,make_smart<ExprConstInt>(1))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:295:6
	makeExtern< void (*)() , ImNodes::EndOutputAttribute , SimNode_ExtFuncCall, imguiTempFn >(lib,"EndOutputAttribute","ImNodes::EndOutputAttribute")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:299:6
	makeExtern< void (*)(int) , ImNodes::BeginStaticAttribute , SimNode_ExtFuncCall, imguiTempFn >(lib,"BeginStaticAttribute","ImNodes::BeginStaticAttribute")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:300:6
	makeExtern< void (*)() , ImNodes::EndStaticAttribute , SimNode_ExtFuncCall, imguiTempFn >(lib,"EndStaticAttribute","ImNodes::EndStaticAttribute")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:303:6
	makeExtern< void (*)(int) , ImNodes::PushAttributeFlag , SimNode_ExtFuncCall, imguiTempFn >(lib,"PushAttributeFlag","ImNodes::PushAttributeFlag")
		->args({"flag"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:304:6
	makeExtern< void (*)() , ImNodes::PopAttributeFlag , SimNode_ExtFuncCall, imguiTempFn >(lib,"PopAttributeFlag","ImNodes::PopAttributeFlag")
		->addToModule(*this, SideEffects::worstDefault);
}
}

