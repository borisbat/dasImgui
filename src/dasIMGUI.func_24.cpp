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
void Module_dasIMGUI::initFunctions_24() {
	using _method_81 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,float,unsigned int,int),&ImDrawList::AddCircleFilled >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2889:21
	makeExtern<DAS_CALL_METHOD(_method_81), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddCircleFilled","das_call_member< void (ImDrawList::*)(const ImVec2 &,float,unsigned int,int) , &ImDrawList::AddCircleFilled >::invoke")
		->args({"self","center","radius","col","num_segments"})
		->arg_init(4,make_smart<ExprConstInt>(0))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_82 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,float,unsigned int,int,float),&ImDrawList::AddNgon >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2890:21
	makeExtern<DAS_CALL_METHOD(_method_82), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddNgon","das_call_member< void (ImDrawList::*)(const ImVec2 &,float,unsigned int,int,float) , &ImDrawList::AddNgon >::invoke")
		->args({"self","center","radius","col","num_segments","thickness"})
		->arg_init(5,make_smart<ExprConstFloat>(1.00000000000000000))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_83 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,float,unsigned int,int),&ImDrawList::AddNgonFilled >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2891:21
	makeExtern<DAS_CALL_METHOD(_method_83), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddNgonFilled","das_call_member< void (ImDrawList::*)(const ImVec2 &,float,unsigned int,int) , &ImDrawList::AddNgonFilled >::invoke")
		->args({"self","center","radius","col","num_segments"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_84 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,unsigned int,float,int,float),&ImDrawList::AddEllipse >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2892:21
	makeExtern<DAS_CALL_METHOD(_method_84), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddEllipse","das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,unsigned int,float,int,float) , &ImDrawList::AddEllipse >::invoke")
		->args({"self","center","radius","col","rot","num_segments","thickness"})
		->arg_init(4,make_smart<ExprConstFloat>(0.00000000000000000))
		->arg_init(5,make_smart<ExprConstInt>(0))
		->arg_init(6,make_smart<ExprConstFloat>(1.00000000000000000))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_85 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,unsigned int,float,int),&ImDrawList::AddEllipseFilled >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2893:21
	makeExtern<DAS_CALL_METHOD(_method_85), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddEllipseFilled","das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,unsigned int,float,int) , &ImDrawList::AddEllipseFilled >::invoke")
		->args({"self","center","radius","col","rot","num_segments"})
		->arg_init(4,make_smart<ExprConstFloat>(0.00000000000000000))
		->arg_init(5,make_smart<ExprConstInt>(0))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_86 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int,float,int),&ImDrawList::AddBezierCubic >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2896:21
	makeExtern<DAS_CALL_METHOD(_method_86), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddBezierCubic","das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int,float,int) , &ImDrawList::AddBezierCubic >::invoke")
		->args({"self","p1","p2","p3","p4","col","thickness","num_segments"})
		->arg_init(7,make_smart<ExprConstInt>(0))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_87 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int,float,int),&ImDrawList::AddBezierQuadratic >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2897:21
	makeExtern<DAS_CALL_METHOD(_method_87), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddBezierQuadratic","das_call_member< void (ImDrawList::*)(const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int,float,int) , &ImDrawList::AddBezierQuadratic >::invoke")
		->args({"self","p1","p2","p3","col","thickness","num_segments"})
		->arg_init(6,make_smart<ExprConstInt>(0))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_88 = das::das_call_member< void (ImDrawList::*)(const ImVec2 *,int,unsigned int,int,float),&ImDrawList::AddPolyline >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2902:21
	makeExtern<DAS_CALL_METHOD(_method_88), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddPolyline","das_call_member< void (ImDrawList::*)(const ImVec2 *,int,unsigned int,int,float) , &ImDrawList::AddPolyline >::invoke")
		->args({"self","points","num_points","col","flags","thickness"})
		->arg_type(4,makeType<ImDrawFlags_>(lib))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_89 = das::das_call_member< void (ImDrawList::*)(const ImVec2 *,int,unsigned int),&ImDrawList::AddConvexPolyFilled >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2903:21
	makeExtern<DAS_CALL_METHOD(_method_89), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddConvexPolyFilled","das_call_member< void (ImDrawList::*)(const ImVec2 *,int,unsigned int) , &ImDrawList::AddConvexPolyFilled >::invoke")
		->args({"self","points","num_points","col"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_90 = das::das_call_member< void (ImDrawList::*)(const ImVec2 *,int,unsigned int),&ImDrawList::AddConcavePolyFilled >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2904:21
	makeExtern<DAS_CALL_METHOD(_method_90), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddConcavePolyFilled","das_call_member< void (ImDrawList::*)(const ImVec2 *,int,unsigned int) , &ImDrawList::AddConcavePolyFilled >::invoke")
		->args({"self","points","num_points","col"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_91 = das::das_call_member< void (ImDrawList::*)(void *,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int),&ImDrawList::AddImage >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2910:21
	makeExtern<DAS_CALL_METHOD(_method_91), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddImage","das_call_member< void (ImDrawList::*)(void *,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int) , &ImDrawList::AddImage >::invoke")
		->args({"self","user_texture_id","p_min","p_max","uv_min","uv_max","col"})
		->arg_init(6,make_smart<ExprConstUInt>(0xffffffff))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_92 = das::das_call_member< void (ImDrawList::*)(void *,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int),&ImDrawList::AddImageQuad >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2911:21
	makeExtern<DAS_CALL_METHOD(_method_92), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddImageQuad","das_call_member< void (ImDrawList::*)(void *,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int) , &ImDrawList::AddImageQuad >::invoke")
		->args({"self","user_texture_id","p1","p2","p3","p4","uv1","uv2","uv3","uv4","col"})
		->arg_init(10,make_smart<ExprConstUInt>(0xffffffff))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_93 = das::das_call_member< void (ImDrawList::*)(void *,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int,float,int),&ImDrawList::AddImageRounded >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2912:21
	makeExtern<DAS_CALL_METHOD(_method_93), SimNode_ExtFuncCall , imguiTempFn>(lib,"AddImageRounded","das_call_member< void (ImDrawList::*)(void *,const ImVec2 &,const ImVec2 &,const ImVec2 &,const ImVec2 &,unsigned int,float,int) , &ImDrawList::AddImageRounded >::invoke")
		->args({"self","user_texture_id","p_min","p_max","uv_min","uv_max","col","rounding","flags"})
		->arg_type(8,makeType<ImDrawFlags_>(lib))
		->arg_init(8,make_smart<ExprConstEnumeration>(0,makeType<ImDrawFlags_>(lib)))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_94 = das::das_call_member< void (ImDrawList::*)(),&ImDrawList::PathClear >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2917:21
	makeExtern<DAS_CALL_METHOD(_method_94), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathClear","das_call_member< void (ImDrawList::*)() , &ImDrawList::PathClear >::invoke")
		->args({"self"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_95 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &),&ImDrawList::PathLineTo >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2918:21
	makeExtern<DAS_CALL_METHOD(_method_95), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathLineTo","das_call_member< void (ImDrawList::*)(const ImVec2 &) , &ImDrawList::PathLineTo >::invoke")
		->args({"self","pos"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_96 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &),&ImDrawList::PathLineToMergeDuplicate >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2919:21
	makeExtern<DAS_CALL_METHOD(_method_96), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathLineToMergeDuplicate","das_call_member< void (ImDrawList::*)(const ImVec2 &) , &ImDrawList::PathLineToMergeDuplicate >::invoke")
		->args({"self","pos"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_97 = das::das_call_member< void (ImDrawList::*)(unsigned int),&ImDrawList::PathFillConvex >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2920:21
	makeExtern<DAS_CALL_METHOD(_method_97), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathFillConvex","das_call_member< void (ImDrawList::*)(unsigned int) , &ImDrawList::PathFillConvex >::invoke")
		->args({"self","col"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_98 = das::das_call_member< void (ImDrawList::*)(unsigned int),&ImDrawList::PathFillConcave >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2921:21
	makeExtern<DAS_CALL_METHOD(_method_98), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathFillConcave","das_call_member< void (ImDrawList::*)(unsigned int) , &ImDrawList::PathFillConcave >::invoke")
		->args({"self","col"})
		->addToModule(*this, SideEffects::worstDefault);
	using _method_99 = das::das_call_member< void (ImDrawList::*)(unsigned int,int,float),&ImDrawList::PathStroke >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2922:21
	makeExtern<DAS_CALL_METHOD(_method_99), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathStroke","das_call_member< void (ImDrawList::*)(unsigned int,int,float) , &ImDrawList::PathStroke >::invoke")
		->args({"self","col","flags","thickness"})
		->arg_type(2,makeType<ImDrawFlags_>(lib))
		->arg_init(2,make_smart<ExprConstEnumeration>(0,makeType<ImDrawFlags_>(lib)))
		->arg_init(3,make_smart<ExprConstFloat>(1.00000000000000000))
		->addToModule(*this, SideEffects::worstDefault);
	using _method_100 = das::das_call_member< void (ImDrawList::*)(const ImVec2 &,float,float,float,int),&ImDrawList::PathArcTo >;
// from D:\daScript\github\daScript/Modules/dasImgui/imgui/imgui.h:2923:21
	makeExtern<DAS_CALL_METHOD(_method_100), SimNode_ExtFuncCall , imguiTempFn>(lib,"PathArcTo","das_call_member< void (ImDrawList::*)(const ImVec2 &,float,float,float,int) , &ImDrawList::PathArcTo >::invoke")
		->args({"self","center","radius","a_min","a_max","num_segments"})
		->arg_init(5,make_smart<ExprConstInt>(0))
		->addToModule(*this, SideEffects::worstDefault);
}
}

