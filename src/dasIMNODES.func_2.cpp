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
	makeExtern< void (*)() , imnodes::BeginNodeEditor , SimNode_ExtFuncCall >(lib,"BeginNodeEditor","imnodes::BeginNodeEditor")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::EndNodeEditor , SimNode_ExtFuncCall >(lib,"EndNodeEditor","imnodes::EndNodeEditor")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::ColorStyle,unsigned int) , imnodes::PushColorStyle , SimNode_ExtFuncCall >(lib,"PushColorStyle","imnodes::PushColorStyle")
		->args({"item","color"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::PopColorStyle , SimNode_ExtFuncCall >(lib,"PopColorStyle","imnodes::PopColorStyle")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::StyleVar,float) , imnodes::PushStyleVar , SimNode_ExtFuncCall >(lib,"PushStyleVar","imnodes::PushStyleVar")
		->args({"style_item","value"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::PopStyleVar , SimNode_ExtFuncCall >(lib,"PopStyleVar","imnodes::PopStyleVar")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int) , imnodes::BeginNode , SimNode_ExtFuncCall >(lib,"BeginNode","imnodes::BeginNode")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::EndNode , SimNode_ExtFuncCall >(lib,"EndNode","imnodes::EndNode")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< ImVec2 (*)(int) , imnodes::GetNodeDimensions , SimNode_ExtFuncCall >(lib,"GetNodeDimensions","imnodes::GetNodeDimensions")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::BeginNodeTitleBar , SimNode_ExtFuncCall >(lib,"BeginNodeTitleBar","imnodes::BeginNodeTitleBar")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::EndNodeTitleBar , SimNode_ExtFuncCall >(lib,"EndNodeTitleBar","imnodes::EndNodeTitleBar")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int,imnodes::PinShape) , imnodes::BeginInputAttribute , SimNode_ExtFuncCall >(lib,"BeginInputAttribute","imnodes::BeginInputAttribute")
		->args({"id","shape"})
		->arg_init(1,make_smart<ExprConstEnumeration>(1,makeType<imnodes::PinShape>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::EndInputAttribute , SimNode_ExtFuncCall >(lib,"EndInputAttribute","imnodes::EndInputAttribute")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int,imnodes::PinShape) , imnodes::BeginOutputAttribute , SimNode_ExtFuncCall >(lib,"BeginOutputAttribute","imnodes::BeginOutputAttribute")
		->args({"id","shape"})
		->arg_init(1,make_smart<ExprConstEnumeration>(1,makeType<imnodes::PinShape>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::EndOutputAttribute , SimNode_ExtFuncCall >(lib,"EndOutputAttribute","imnodes::EndOutputAttribute")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int) , imnodes::BeginStaticAttribute , SimNode_ExtFuncCall >(lib,"BeginStaticAttribute","imnodes::BeginStaticAttribute")
		->args({"id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::EndStaticAttribute , SimNode_ExtFuncCall >(lib,"EndStaticAttribute","imnodes::EndStaticAttribute")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::AttributeFlags) , imnodes::PushAttributeFlag , SimNode_ExtFuncCall >(lib,"PushAttributeFlag","imnodes::PushAttributeFlag")
		->args({"flag"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)() , imnodes::PopAttributeFlag , SimNode_ExtFuncCall >(lib,"PopAttributeFlag","imnodes::PopAttributeFlag")
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(int,int,int) , imnodes::Link , SimNode_ExtFuncCall >(lib,"Link","imnodes::Link")
		->args({"id","start_attribute_id","end_attribute_id"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

