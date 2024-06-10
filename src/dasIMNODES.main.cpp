#include "daScript/misc/platform.h"
#include "daScript/ast/ast.h"
#include "daScript/ast/ast_interop.h"
#include "daScript/ast/ast_handle.h"
#include "daScript/ast/ast_typefactory_bind.h"
#include "daScript/simulate/bind_enum.h"
#include "dasIMNODES.h"
#include "need_dasIMNODES.h"
#include "aot_dasIMNODES.h"

namespace das {

    void Module_dasIMNODES::initAotAlias () {
    }

	void Module_dasIMNODES::initMain () {
        findUniqueFunction("BeginInputAttribute")
            ->arg_init(1, make_smart<ExprConstEnumeration>("CircleFilled",makeType<ImNodesPinShape>(lib)));
        findUniqueFunction("BeginOutputAttribute")
            ->arg_init(1, make_smart<ExprConstEnumeration>("CircleFilled",makeType<ImNodesPinShape>(lib)));
        // time to fix-up const & ImVec2 and const & ImVec4
        for ( auto & pfn : this->functions.each() ) {
            for ( auto & arg : pfn->arguments ) {
                if ( arg->type->constant && arg->type->ref && arg->type->dim.size()==0 ) {
                    if ( arg->type->baseType==Type::tFloat2 || arg->type->baseType==Type::tFloat4 ) {
                        arg->type->ref = false;
                    }
                }
            }
        }
    }

	ModuleAotType Module_dasIMNODES::aotRequire ( TextWriter & tw ) const {
        // add your stuff here
        tw << "#include \"../modules/dasImgui/src/imnodes_stub.h\"\n";
        tw << "#include \"../modules/dasImgui/src/aot_dasIMNODES.h\"\n";
        tw << "#include \"daScript/simulate/bind_enum.h\"\n";
        tw << "#include \"../modules/dasImgui/src/dasIMNODES.enum.decl.cast.inc\"\n";
        // specifying AOT type, in this case direct cpp mode (and not hybrid mode)
        return ModuleAotType::cpp;
    }

}
