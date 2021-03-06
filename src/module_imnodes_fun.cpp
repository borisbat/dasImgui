#include "daScript/daScript.h"
#include "daScript/ast/ast_typefactory_bind.h"

#include <imgui.h>
#include <imnodes.h>

using namespace das;

#include "need_imgui.h"

#if USE_GENERATED

#define IMNODES_NAMESPACE    1

#include "module_imgui.h"

#endif

void Module_imnodes::initFunctions() {
#if USE_GENERATED
#include "module_imgui.inc"
#endif
}
