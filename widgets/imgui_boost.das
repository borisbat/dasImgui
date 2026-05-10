options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_boost_v2 shared

require imgui public
require imgui/imgui_boost_runtime public
require daslib/ast
require daslib/ast_boost
require daslib/strings_boost
require daslib/templates_boost

//! `[widget]` function annotation.
//!
//! Mark `def myWidget(var state : MyState; <args>) : <ret>` with `[widget]`
//! to register it. The macro:
//!   1. Injects `widget_ident : string` between the state arg and the rest
//!      so the body can call `widget_finalize(widget_ident, ...)`.
//!   2. Injects `widget_prelude(widget_ident)` at the body's top (`PushID`).
//!   3. Registers a per-kind call_macro that intercepts user-side
//!      `myWidget(IDENT, ...)` calls, parses the dotted-suffix flag chain
//!      (`SAVE_BTN.PUBLIC` / `RPS.NOTLIVE` etc.), idempotently emits IDENT
//!      as a module-scope state global, and rewrites the call to
//!      `myWidget(IDENT, "IDENT", ...)`.
//!
//! Auto-emit is module-scope only (find_variable gate). UPPER_SNAKE_CASE
//! identifiers by convention (API_REWORK §4.5).

let private VALID_FLAGS : array<string> = ["PUBLIC", "PRIVATE", "NOTLIVE"]

[function_macro(name = "widget")]
class WidgetFunctionMacro : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        return apply_widget_or_container(func, errors, false)
    }
}

//! `[container]` function annotation — block-arg sibling of `[widget]`.
//!
//! Mark `def myContainer(var state : MyState; <args>; blk : block)` with
//! `[container]` to register a Begin/End-shaped wrapper. The macro:
//!   1. Same widget_ident injection + auto-emit + dotted-flag handling as
//!      `[widget]`.
//!   2. Prepends `container_path_push(widget_ident)` to the body so leaf
//!      widgets rendered inside `invoke(blk)` see this container in
//!      `g_container_path`.
//!   3. Appends `container_path_pop()` to body.finalList so the path is
//!      popped even when the user body returns early.
//!
//! Begin/End semantics — which paint always vs only-on-true — are NOT
//! abstracted. Each container def authors its own Begin → invoke(blk) → End
//! sequence so the imgui-irregular pairing rules stay visible at the call
//! site (Begin/End and BeginChild/EndChild always-pair; everything else
//! End-only-on-true).

[function_macro(name = "container")]
class ContainerFunctionMacro : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        if (empty(func.arguments) || func.arguments[length(func.arguments) - 1]._type == null
            || func.arguments[length(func.arguments) - 1]._type.baseType != Type.tBlock) {
            errors := "[container] requires the last parameter to be `blk : block`"
            return false
        }
        return apply_widget_or_container(func, errors, true)
    }
}

def private apply_widget_or_container(var func : FunctionPtr; var errors : das_string;
                                      is_container : bool) : bool {
    if (empty(func.arguments)) {
        errors := "[widget]/[container] requires at least one parameter (state struct)"
        return false
    }
    let kind = string(func.name)
    let stateArg = func.arguments[0]
    if (stateArg._type == null || stateArg._type.structType == null) {
        errors := "[widget]/[container] first parameter must be a struct (state)"
        return false
    }
    let stateTypeName = describe(stateArg._type)
    let stateStruct = stateArg._type.structType
    func.flags |= FunctionFlags.generated
    // Inject widget_ident : string at index 1 (between state and rest).
    // The user's body code references `widget_ident` literally when
    // calling widget_finalize / container_finalize — this param makes it in scope.
    var widthIdentVar = new Variable(at = func.at,
        name := "widget_ident",
        _type <- new TypeDecl(baseType = Type.tString, at = func.at))
    widthIdentVar.flags |= VariableFlags.generated
    func.arguments |> emplace(widthIdentVar, 1)
    // Wrap the body: prepend widget_prelude(widget_ident) and, for containers,
    // container_path_push(widget_ident). The container path push runs every
    // frame BEFORE the user body so `invoke(blk)` sees self in g_container_path
    // and any leaves rendered inside get hierarchical registry keys. The
    // matching pop lives in body.finalList (always-runs on normal return).
    // PopID lives in widget_finalize / container_finalize at the bottom.
    var fblk = new ExprBlock(at = func.body.at)
    fblk.list |> push(qmacro(widget_prelude($i("widget_ident"))))
    if (is_container) {
        fblk.list |> push(qmacro(container_path_push($i("widget_ident"))))
    }
    let oldBody = func.body as ExprBlock
    for (el in oldBody.list) {
        fblk.list |> push(clone_expression(el))
    }
    for (ef in oldBody.finalList) {
        fblk.finalList |> push(clone_expression(ef))
    }
    if (is_container) {
        fblk.finalList |> push(qmacro(container_path_pop()))
    }
    func.body = fblk
    // Register the per-kind call macro instance. The same WidgetCallMacro
    // class works for both widgets and containers: it rewrites `kind(IDENT, ...)`
    // to `kind(IDENT, "IDENT", ...)` and auto-emits the global. The body
    // wrapping (path push/pop) is the only macro-side difference between the
    // two annotations. Duplicate-name collisions trigger a C++-side panic in
    // add_call_macro.
    var inst = new WidgetCallMacro(
        kind_name = kind,
        state_type_name = stateTypeName,
        state_struct = stateStruct,
        render_fn_name = kind)
    compiling_module() |> add_call_macro(make_call_macro(kind, inst))
    return true
}

class WidgetCallMacro : AstCallMacro {
    kind_name : string
    state_type_name : string
    state_struct : Structure const?
    render_fn_name : string

    def override canVisitArgument(expr : ExprCallMacro?; argIndex : int) : bool {
        // The first argument is the IDENT (which doesn't yet exist as a
        // global); telling the typer not to pre-resolve it lets us see the
        // raw ExprVar in visit(), parse the dotted-flag chain, emit the
        // global, and rewrite. Other args resolve normally before we see them.
        return argIndex != 0
    }

    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        if (empty(expr.arguments)) {
            macro_error(prog, expr.at, "{kind_name}(IDENT, ...): missing widget identifier")
            return <- default<ExpressionPtr>
        }
        // Walk the leading-arg AST to extract `BARE.FLAG1.FLAG2...`. Plain
        // `BARE` is a single ExprVar; dotted forms like `SAVE_BTN.PUBLIC` parse
        // as nested ExprField (field accesses), outermost-to-innermost. Walk
        // down, collecting field names as flag tokens, until the leaf ExprVar.
        var bareName : string
        var rawName : string
        var flagsReversed : array<string>
        var cursor : Expression const? = expr.arguments[0]
        while (cursor is ExprField) {
            let fld = cursor as ExprField
            flagsReversed |> push(string(fld.name))
            cursor = fld.value
        }
        if (cursor is ExprVar) {
            bareName = string((cursor as ExprVar).name)
        } else {
            macro_error(prog, expr.at, "{kind_name}(IDENT...): first argument must be an identifier or `IDENT.FLAG[.FLAG...]`, got {describe(expr.arguments[0])}")
            return <- default<ExpressionPtr>
        }
        // Reconstruct rawName for error messages (source order).
        rawName = build_string() $(var w) {
            w |> write(bareName)
            for (i in range(0, length(flagsReversed))) {
                w |> write(".")
                w |> write(flagsReversed[length(flagsReversed) - 1 - i])
            }
        }
        if (empty(bareName)) {
            macro_error(prog, expr.at, "{kind_name}(IDENT...): identifier must not be empty: '{rawName}'")
            return <- default<ExpressionPtr>
        }
        // Validate + record flags.
        var flagPublic = false
        var flagPrivate = false
        var flagNotLive = false
        for (token in flagsReversed) {
            if (empty(token)) {
                macro_error(prog, expr.at, "{kind_name}(IDENT...): empty flag in '{rawName}'")
                return <- default<ExpressionPtr>
            }
            var known = false
            for (vf in VALID_FLAGS) {
                if (token == vf) {
                    known = true
                }
            }
            if (!known) {
                macro_error(prog, expr.at, "{kind_name}(IDENT...): unknown flag '{token}' in '{rawName}'; valid: PUBLIC, PRIVATE, NOTLIVE")
                return <- default<ExpressionPtr>
            }
            if (token == "PUBLIC") {
                if (flagPublic) {
                    macro_error(prog, expr.at, "{kind_name}(IDENT...): duplicate flag 'PUBLIC' in '{rawName}'")
                    return <- default<ExpressionPtr>
                }
                flagPublic = true
            } elif (token == "PRIVATE") {
                if (flagPrivate) {
                    macro_error(prog, expr.at, "{kind_name}(IDENT...): duplicate flag 'PRIVATE' in '{rawName}'")
                    return <- default<ExpressionPtr>
                }
                flagPrivate = true
            } elif (token == "NOTLIVE") {
                if (flagNotLive) {
                    macro_error(prog, expr.at, "{kind_name}(IDENT...): duplicate flag 'NOTLIVE' in '{rawName}'")
                    return <- default<ExpressionPtr>
                }
                flagNotLive = true
            }
        }
        if (flagPublic && flagPrivate) {
            macro_error(prog, expr.at, "{kind_name}(IDENT...): cannot combine PUBLIC and PRIVATE in '{rawName}'")
            return <- default<ExpressionPtr>
        }
        // Auto-emit gate: only emit if not already declared at module scope.
        // find_variable is module-scope ONLY — re-uses existing globals.
        // Type built from the captured Structure pointer (NOT Type.alias on
        // the qualified name — that doesn't resolve at the caller's scope
        // when the state struct lives in another module).
        // Initializer = `T()` so struct field defaults fire (without it the
        // global is bare zero-init and `field : T = default` declarations are
        // silently lost — see useInitializer flag, equivalent to gen2 `T()`).
        if (find_variable(mod, bareName) == null) {
            var typeRef <- new TypeDecl(baseType = Type.tStructure,
                                        structType = unsafe(reinterpret<Structure?>(state_struct)),
                                        at = expr.at)
            var initCall = new ExprMakeStruct(at = expr.at, makeType = clone_type(typeRef))
            initCall.makeStructFlags |= ExprMakeStructFlags.useInitializer
            var v = new Variable(at = expr.at,
                name := bareName,
                _type <- typeRef,
                init = initCall)
            v.flags |= VariableFlags.generated
            if (!flagPublic) {
                v.flags |= VariableFlags.private_variable
            }
            if (!flagNotLive) {
                v.annotation |> add_annotation_argument("live", true)
            }
            mod |> add_variable(v)
            // Phase 1: append a register_widget call into the per-module
            // shared [init] function. setup_call_list creates the function
            // on first call and returns its body block on subsequent ones,
            // so all widgets in this module funnel into a single init
            // function. Pattern from daslib/decs_boost.das:585.
            //
            // First widget in this module: prepend a clear_module_widgets
            // call so reload re-fires the init and replaces stale entries
            // (including removed widgets and stale captured lambdas) with
            // fresh ones. Other modules' entries stay untouched.
            var reg <- setup_call_list("register`imgui`widgets", expr.at, true, true)
            let kindLit = kind_name
            let identLit = bareName
            let modLit = string(mod.name)
            if (empty(reg.list)) {
                reg.list |> push(qmacro(
                    imgui_boost_runtime::clear_module_widgets($v(modLit))
                ))
            }
            reg.list |> push(qmacro(
                imgui_boost_runtime::register_widget(
                    $v(modLit),
                    $v(identLit),
                    $v(kindLit),
                    unsafe(addr($i(identLit))),
                    @() : JsonValue? {
                        return JV($i(identLit))
                    }
                )
            ))
        }
        // Rewrite to `<kind>(IDENT, "IDENT", args...)`. The function lives
        // in imgui_widgets_builtin (or user module). After macro expansion
        // the typer resolves the call against the (macro-expanded) signature
        // `def kind(var state : T; widget_ident : string; ...)`.
        //
        // Named-tuple args `(name = val, ...)` carry the call's named-arg
        // ergonomic; daslang's square-bracket `[name = val]` form builds an
        // ExprNamedCall and bypasses call_macro dispatch entirely. Destructure
        // named tuples into positional args (in source order — matches the
        // user-facing parameter order).
        var newCall = new ExprCall(at = expr.at, name := render_fn_name)
        newCall.arguments |> push(new ExprVar(at = expr.at, name := bareName))
        newCall.arguments |> push(new ExprConstString(at = expr.at, value := bareName))
        for (i in range(1, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (v in mt.values) {
                        newCall.arguments |> push(clone_expression(v))
                    }
                    continue
                }
            }
            newCall.arguments |> push(clone_expression(a))
        }
        return <- newCall
    }
}
