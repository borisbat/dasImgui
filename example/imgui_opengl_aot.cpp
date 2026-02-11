#include "daScript/daScript.h"
#include "daScript/simulate/fs_file_info.h"

using namespace das;

TextPrinter tout;

bool pauseAfterErrors = false;

void compile_and_run ( const string & fn, const string & mainFnName, bool outputProgramCode ) {
    auto access = make_smart<FsFileAccess>();
    ModuleGroup dummyGroup;
    CodeOfPolicies policies;
    policies.aot = true;
    if ( auto program = compileDaScript(fn,access,tout,dummyGroup,policies) ) {
        if ( program->failed() ) {
            for ( auto & err : program->errors ) {
                tout << reportError(err.at, err.what, err.extra, err.fixme, err.cerr );
            }
            if ( pauseAfterErrors ) {
                getchar();
            }
        } else {
            if ( outputProgramCode )
                tout << *program << "\n";
            Context ctx(program->getContextStackSize());
            program->simulate(ctx, tout);
            if ( auto fnTest = ctx.findFunction(mainFnName.c_str()) ) {
                ctx.restart();
                ctx.eval(fnTest, nullptr);
            } else {
                tout << "function '"  << mainFnName << " ' not found\n";
            }
        }
    }
}

namespace das { vector<void *> force_aot_stub(); }

int main(int argc, char * argv[]) {
    // force libDaScriptAot linking
    force_aot_stub();
    // command line arguments
    setCommandLineArguments(argc,argv);
    // register modules
    NEED_MODULE(Module_BuiltIn);
    NEED_MODULE(Module_Math);
    NEED_MODULE(Module_Strings);
    NEED_MODULE(Module_Rtti);
    NEED_MODULE(Module_Ast);
    NEED_MODULE(Module_Debugger);
    NEED_MODULE(Module_Network);
    NEED_MODULE(Module_UriParser);
    NEED_MODULE(Module_JobQue);
    NEED_MODULE(Module_FIO);
    NEED_MODULE(Module_DASBIND);
    NEED_MODULE(Module_dasIMGUI);
    NEED_MODULE(Module_dasIMNODES);
    NEED_MODULE(Module_dasIMGUI_NODE_EDITOR);
    NEED_MODULE(Module_imgui_app);
    Module::Initialize();
    // compile and run
    string demoName = getDasRoot() + "/modules/dasImgui/example/imgui_opengl2.das";
    compile_and_run(demoName, "main", false);
    Module::Shutdown();
    return 0;
}


