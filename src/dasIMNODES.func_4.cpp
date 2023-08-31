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
	makeExtern< bool (*)(int *,bool) , imnodes::IsLinkDropped , SimNode_ExtFuncCall >(lib,"IsLinkDropped","imnodes::IsLinkDropped")
		->args({"started_at_attribute_id","including_detached_links"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->arg_init(1,make_smart<ExprConstBool>(true))
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *,int *,bool *) , imnodes::IsLinkCreated , SimNode_ExtFuncCall >(lib,"IsLinkCreated","imnodes::IsLinkCreated")
		->args({"started_at_attribute_id","ended_at_attribute_id","created_from_snap"})
		->arg_init(2,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *,int *,int *,int *,bool *) , imnodes::IsLinkCreated , SimNode_ExtFuncCall >(lib,"IsLinkCreated","imnodes::IsLinkCreated")
		->args({"started_at_node_id","started_at_attribute_id","ended_at_node_id","ended_at_attribute_id","created_from_snap"})
		->arg_init(4,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< bool (*)(int *) , imnodes::IsLinkDestroyed , SimNode_ExtFuncCall >(lib,"IsLinkDestroyed","imnodes::IsLinkDestroyed")
		->args({"link_id"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< const char * (*)(size_t *) , imnodes::SaveCurrentEditorStateToIniString , SimNode_ExtFuncCall >(lib,"SaveCurrentEditorStateToIniString","imnodes::SaveCurrentEditorStateToIniString")
		->args({"data_size"})
		->arg_init(0,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< const char * (*)(const imnodes::EditorContext *,size_t *) , imnodes::SaveEditorStateToIniString , SimNode_ExtFuncCall >(lib,"SaveEditorStateToIniString","imnodes::SaveEditorStateToIniString")
		->args({"editor","data_size"})
		->arg_init(1,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(const char *,size_t) , imnodes::LoadCurrentEditorStateFromIniString , SimNode_ExtFuncCall >(lib,"LoadCurrentEditorStateFromIniString","imnodes::LoadCurrentEditorStateFromIniString")
		->args({"data","data_size"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::EditorContext *,const char *,size_t) , imnodes::LoadEditorStateFromIniString , SimNode_ExtFuncCall >(lib,"LoadEditorStateFromIniString","imnodes::LoadEditorStateFromIniString")
		->args({"editor","data","data_size"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(const char *) , imnodes::SaveCurrentEditorStateToIniFile , SimNode_ExtFuncCall >(lib,"SaveCurrentEditorStateToIniFile","imnodes::SaveCurrentEditorStateToIniFile")
		->args({"file_name"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(const imnodes::EditorContext *,const char *) , imnodes::SaveEditorStateToIniFile , SimNode_ExtFuncCall >(lib,"SaveEditorStateToIniFile","imnodes::SaveEditorStateToIniFile")
		->args({"editor","file_name"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(const char *) , imnodes::LoadCurrentEditorStateFromIniFile , SimNode_ExtFuncCall >(lib,"LoadCurrentEditorStateFromIniFile","imnodes::LoadCurrentEditorStateFromIniFile")
		->args({"file_name"})
		->addToModule(*this, SideEffects::worstDefault);
	makeExtern< void (*)(imnodes::EditorContext *,const char *) , imnodes::LoadEditorStateFromIniFile , SimNode_ExtFuncCall >(lib,"LoadEditorStateFromIniFile","imnodes::LoadEditorStateFromIniFile")
		->args({"editor","file_name"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

