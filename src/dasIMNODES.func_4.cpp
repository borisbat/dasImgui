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
void Module_dasIMNODES::initFunctions_4() {
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:361:6
	makeExtern< bool (*)(int) , ImNodes::IsNodeSelected , SimNode_ExtFuncCall >(lib,"IsNodeSelected","ImNodes::IsNodeSelected")
		->args({"node_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:362:6
	makeExtern< void (*)(int) , ImNodes::SelectLink , SimNode_ExtFuncCall >(lib,"SelectLink","ImNodes::SelectLink")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:363:6
	makeExtern< void (*)(int) , ImNodes::ClearLinkSelection , SimNode_ExtFuncCall >(lib,"ClearLinkSelection","ImNodes::ClearLinkSelection")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:364:6
	makeExtern< bool (*)(int) , ImNodes::IsLinkSelected , SimNode_ExtFuncCall >(lib,"IsLinkSelected","ImNodes::IsLinkSelected")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:368:6
	makeExtern< bool (*)() , ImNodes::IsAttributeActive , SimNode_ExtFuncCall >(lib,"IsAttributeActive","ImNodes::IsAttributeActive")
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:370:6
	makeExtern< bool (*)(int *) , ImNodes::IsAnyAttributeActive , SimNode_ExtFuncCall >(lib,"IsAnyAttributeActive","ImNodes::IsAnyAttributeActive")
		->args({"attribute_id"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:376:6
	makeExtern< bool (*)(int *) , ImNodes::IsLinkStarted , SimNode_ExtFuncCall >(lib,"IsLinkStarted","ImNodes::IsLinkStarted")
		->args({"started_at_attribute_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:383:6
	makeExtern< bool (*)(int *,bool) , ImNodes::IsLinkDropped , SimNode_ExtFuncCall >(lib,"IsLinkDropped","ImNodes::IsLinkDropped")
		->args({"started_at_attribute_id","including_detached_links"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->arg_init(1,make_smart<ExprConstBool>(true))
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:385:6
	makeExtern< bool (*)(int *,int *,bool *) , ImNodes::IsLinkCreated , SimNode_ExtFuncCall >(lib,"IsLinkCreated","ImNodes::IsLinkCreated")
		->args({"started_at_attribute_id","ended_at_attribute_id","created_from_snap"})
		->arg_init(2,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:389:6
	makeExtern< bool (*)(int *,int *,int *,int *,bool *) , ImNodes::IsLinkCreated , SimNode_ExtFuncCall >(lib,"IsLinkCreated","ImNodes::IsLinkCreated")
		->args({"started_at_node_id","started_at_attribute_id","ended_at_node_id","ended_at_attribute_id","created_from_snap"})
		->arg_init(4,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:398:6
	makeExtern< bool (*)(int *) , ImNodes::IsLinkDestroyed , SimNode_ExtFuncCall >(lib,"IsLinkDestroyed","ImNodes::IsLinkDestroyed")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:403:13
	makeExtern< const char * (*)(size_t *) , ImNodes::SaveCurrentEditorStateToIniString , SimNode_ExtFuncCall >(lib,"SaveCurrentEditorStateToIniString","ImNodes::SaveCurrentEditorStateToIniString")
		->args({"data_size"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:404:13
	makeExtern< const char * (*)(const ImNodesEditorContext *,size_t *) , ImNodes::SaveEditorStateToIniString , SimNode_ExtFuncCall >(lib,"SaveEditorStateToIniString","ImNodes::SaveEditorStateToIniString")
		->args({"editor","data_size"})
		->arg_init(1,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:408:6
	makeExtern< void (*)(const char *,size_t) , ImNodes::LoadCurrentEditorStateFromIniString , SimNode_ExtFuncCall >(lib,"LoadCurrentEditorStateFromIniString","ImNodes::LoadCurrentEditorStateFromIniString")
		->args({"data","data_size"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:409:6
	makeExtern< void (*)(ImNodesEditorContext *,const char *,size_t) , ImNodes::LoadEditorStateFromIniString , SimNode_ExtFuncCall >(lib,"LoadEditorStateFromIniString","ImNodes::LoadEditorStateFromIniString")
		->args({"editor","data","data_size"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:411:6
	makeExtern< void (*)(const char *) , ImNodes::SaveCurrentEditorStateToIniFile , SimNode_ExtFuncCall >(lib,"SaveCurrentEditorStateToIniFile","ImNodes::SaveCurrentEditorStateToIniFile")
		->args({"file_name"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:412:6
	makeExtern< void (*)(const ImNodesEditorContext *,const char *) , ImNodes::SaveEditorStateToIniFile , SimNode_ExtFuncCall >(lib,"SaveEditorStateToIniFile","ImNodes::SaveEditorStateToIniFile")
		->args({"editor","file_name"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:414:6
	makeExtern< void (*)(const char *) , ImNodes::LoadCurrentEditorStateFromIniFile , SimNode_ExtFuncCall >(lib,"LoadCurrentEditorStateFromIniFile","ImNodes::LoadCurrentEditorStateFromIniFile")
		->args({"file_name"})
		->addToModule(*this, SideEffects::worstDefault);
// from D:\daScript\github\daScript/Modules/dasImgui/imnodes/imnodes.h:415:6
	makeExtern< void (*)(ImNodesEditorContext *,const char *) , ImNodes::LoadEditorStateFromIniFile , SimNode_ExtFuncCall >(lib,"LoadEditorStateFromIniFile","ImNodes::LoadEditorStateFromIniFile")
		->args({"editor","file_name"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

