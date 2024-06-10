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
void Module_dasIMGUI::initFunctions_22() {
	using _method_45 = das::das_call_member< void (ImGuiStorage::*)(unsigned int,float),&ImGuiStorage::SetFloat >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2561:25
	makeExtern<DAS_CALL_METHOD(_method_45), SimNode_ExtFuncCall , imguiTempFn>(lib,"SetFloat","das_call_member< void (ImGuiStorage::*)(unsigned int,float) , &ImGuiStorage::SetFloat >::invoke")
		->args({"self","key","val"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_46 = das::das_call_member< void * (ImGuiStorage::*)(unsigned int) const,&ImGuiStorage::GetVoidPtr >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2562:25
	makeExtern<DAS_CALL_METHOD(_method_46), SimNode_ExtFuncCall , imguiTempFn>(lib,"GetVoidPtr","das_call_member< void * (ImGuiStorage::*)(unsigned int) const , &ImGuiStorage::GetVoidPtr >::invoke")
		->args({"self","key"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_47 = das::das_call_member< void (ImGuiStorage::*)(unsigned int,void *),&ImGuiStorage::SetVoidPtr >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2563:25
	makeExtern<DAS_CALL_METHOD(_method_47), SimNode_ExtFuncCall , imguiTempFn>(lib,"SetVoidPtr","das_call_member< void (ImGuiStorage::*)(unsigned int,void *) , &ImGuiStorage::SetVoidPtr >::invoke")
		->args({"self","key","val"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_48 = das::das_call_member< int * (ImGuiStorage::*)(unsigned int,int),&ImGuiStorage::GetIntRef >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2569:25
	makeExtern<DAS_CALL_METHOD(_method_48), SimNode_ExtFuncCall , imguiTempFn>(lib,"GetIntRef","das_call_member< int * (ImGuiStorage::*)(unsigned int,int) , &ImGuiStorage::GetIntRef >::invoke")
		->args({"self","key","default_val"})
		->arg_init(2,make_smart<ExprConstInt>(0))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_49 = das::das_call_member< bool * (ImGuiStorage::*)(unsigned int,bool),&ImGuiStorage::GetBoolRef >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2570:25
	makeExtern<DAS_CALL_METHOD(_method_49), SimNode_ExtFuncCall , imguiTempFn>(lib,"GetBoolRef","das_call_member< bool * (ImGuiStorage::*)(unsigned int,bool) , &ImGuiStorage::GetBoolRef >::invoke")
		->args({"self","key","default_val"})
		->arg_init(2,make_smart<ExprConstBool>(false))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_50 = das::das_call_member< float * (ImGuiStorage::*)(unsigned int,float),&ImGuiStorage::GetFloatRef >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2571:25
	makeExtern<DAS_CALL_METHOD(_method_50), SimNode_ExtFuncCall , imguiTempFn>(lib,"GetFloatRef","das_call_member< float * (ImGuiStorage::*)(unsigned int,float) , &ImGuiStorage::GetFloatRef >::invoke")
		->args({"self","key","default_val"})
		->arg_init(2,make_smart<ExprConstFloat>(0.00000000000000000))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_51 = das::das_call_member< void ** (ImGuiStorage::*)(unsigned int,void *),&ImGuiStorage::GetVoidPtrRef >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2572:25
	makeExtern<DAS_CALL_METHOD(_method_51), SimNode_ExtFuncCall , imguiTempFn>(lib,"GetVoidPtrRef","das_call_member< void ** (ImGuiStorage::*)(unsigned int,void *) , &ImGuiStorage::GetVoidPtrRef >::invoke")
		->args({"self","key","default_val"})
		->arg_init(2,make_smart<ExprConstPtr>())
		->addToModule(*this, SideEffects::worstDefault);
	using _method_52 = das::das_call_member< void (ImGuiStorage::*)(),&ImGuiStorage::BuildSortByKey >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2575:25
	makeExtern<DAS_CALL_METHOD(_method_52), SimNode_ExtFuncCall , imguiTempFn>(lib,"BuildSortByKey","das_call_member< void (ImGuiStorage::*)() , &ImGuiStorage::BuildSortByKey >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_53 = das::das_call_member< void (ImGuiStorage::*)(int),&ImGuiStorage::SetAllInt >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2577:25
	makeExtern<DAS_CALL_METHOD(_method_53), SimNode_ExtFuncCall , imguiTempFn>(lib,"SetAllInt","das_call_member< void (ImGuiStorage::*)(int) , &ImGuiStorage::SetAllInt >::invoke")
		->args({"self","val"})
		->addToModule(*this, SideEffects::worstDefault);
	addCtorAndUsing<ImGuiListClipper>(*this,lib,"ImGuiListClipper","ImGuiListClipper");
	using _method_54 = das::das_call_member< void (ImGuiListClipper::*)(int,float),&ImGuiListClipper::Begin >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2614:21
	makeExtern<DAS_CALL_METHOD(_method_54), SimNode_ExtFuncCall , imguiTempFn>(lib,"Begin","das_call_member< void (ImGuiListClipper::*)(int,float) , &ImGuiListClipper::Begin >::invoke")
		->args({"self","items_count","items_height"})
		->arg_init(2,make_smart<ExprConstFloat>(-1.00000000000000000))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_55 = das::das_call_member< void (ImGuiListClipper::*)(),&ImGuiListClipper::End >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2615:21
	makeExtern<DAS_CALL_METHOD(_method_55), SimNode_ExtFuncCall , imguiTempFn>(lib,"End","das_call_member< void (ImGuiListClipper::*)() , &ImGuiListClipper::End >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_56 = das::das_call_member< bool (ImGuiListClipper::*)(),&ImGuiListClipper::Step >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2616:21
	makeExtern<DAS_CALL_METHOD(_method_56), SimNode_ExtFuncCall , imguiTempFn>(lib,"Step","das_call_member< bool (ImGuiListClipper::*)() , &ImGuiListClipper::Step >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_57 = das::das_call_member< void (ImGuiListClipper::*)(int),&ImGuiListClipper::IncludeItemByIndex >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2620:21
	makeExtern<DAS_CALL_METHOD(_method_57), SimNode_ExtFuncCall , imguiTempFn>(lib,"IncludeItemByIndex","das_call_member< void (ImGuiListClipper::*)(int) , &ImGuiListClipper::IncludeItemByIndex >::invoke")
		->args({"self","item_index"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_58 = das::das_call_member< void (ImGuiListClipper::*)(int,int),&ImGuiListClipper::IncludeItemsByIndex >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2621:21
	makeExtern<DAS_CALL_METHOD(_method_58), SimNode_ExtFuncCall , imguiTempFn>(lib,"IncludeItemsByIndex","das_call_member< void (ImGuiListClipper::*)(int,int) , &ImGuiListClipper::IncludeItemsByIndex >::invoke")
		->args({"self","item_begin","item_end"})
		->addToModule(*this, SideEffects::worstDefault);
	addCtorAndUsing<ImDrawCmd>(*this,lib,"ImDrawCmd","ImDrawCmd");
	using _method_59 = das::das_call_member< void * (ImDrawCmd::*)() const,&ImDrawCmd::GetTexID >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2748:24
	makeExtern<DAS_CALL_METHOD(_method_59), SimNode_ExtFuncCall , imguiTempFn>(lib,"GetTexID","das_call_member< void * (ImDrawCmd::*)() const , &ImDrawCmd::GetTexID >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
	addCtorAndUsing<ImDrawListSplitter>(*this,lib,"ImDrawListSplitter","ImDrawListSplitter");
	using _method_60 = das::das_call_member< void (ImDrawListSplitter::*)(),&ImDrawListSplitter::Clear >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2793:33
	makeExtern<DAS_CALL_METHOD(_method_60), SimNode_ExtFuncCall , imguiTempFn>(lib,"Clear","das_call_member< void (ImDrawListSplitter::*)() , &ImDrawListSplitter::Clear >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_61 = das::das_call_member< void (ImDrawListSplitter::*)(),&ImDrawListSplitter::ClearFreeMemory >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2794:33
	makeExtern<DAS_CALL_METHOD(_method_61), SimNode_ExtFuncCall , imguiTempFn>(lib,"ClearFreeMemory","das_call_member< void (ImDrawListSplitter::*)() , &ImDrawListSplitter::ClearFreeMemory >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
}
}

