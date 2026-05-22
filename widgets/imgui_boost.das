options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_boost_v2 shared

require imgui public
require imgui/imgui_lint public
require imgui/imgui_boost_runtime public
require daslib/ast
require daslib/ast_boost
require daslib/strings_boost
require daslib/templates_boost

// `[widget]` / `[container]` function annotations. Architectural detail
// (widget_ident injection, dotted-flag parsing, auto-emit of state
// globals) lives in handmade/module-imgui_boost_v2.rst and API_REWORK §4.5.

let private VALID_FLAGS : array<string> = ["PUBLIC", "PRIVATE", "NOTLIVE"]

// Named-arg sugar that flows into the auto-emitted state global's
// initializer instead of the widget render call. `init=` is a rename
// (sugar for `value`); `bounds=` matches the state field name verbatim.
// `range=` is reserved in daslang's grammar and unusable as a record
// name, hence the rename pair. Per API_REWORK §4.2 + §9.1.
def private init_arg_to_field(name : string) : string {
    return "value" if (name == "init")
    return "bounds" if (name == "bounds")
    return ""
}

[function_macro(name = "widget")]
class WidgetFunctionMacro : AstFunctionAnnotation {
    //! ``[widget]`` annotation — registers ``def fn(var state : ST, ...)`` as a stateful widget. Auto-emits the state global, injects ``widget_ident``, and installs a per-kind call_macro for dotted-flag parsing.
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        return apply_widget_or_container(func, errors, false)
    }
}

[function_macro(name = "container")]
class ContainerFunctionMacro : AstFunctionAnnotation {
    //! ``[container]`` annotation — block-arg sibling of ``[widget]``; same identifier auto-emit, plus ``container_path_push``/``pop`` around ``invoke(blk)`` so leaf telemetry paths nest correctly.
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

// `[drawlist_prim]` mirrors `[widget]` but skips state-global synthesis.
// The annotation injects `widget_ident : string` at position 0 of the
// function's arguments; the per-kind `DrawlistPrimCallMacro` rewrites
// each call site, prepending a fresh `ExprConstString("<mod>:<line>:<col>")`
// as the first positional arg. No `__widget_<line>_<col>` global is
// emitted; the registry entry alone is enough for mouse-cards / playwright
// targeting because drawlist primitives don't carry interactive state
// worth pinning across `@live` reload.

class DrawlistPrimCallMacro : AstCallMacro {
    kind_name : string

    def override visit(prog : ProgramPtr; mod : Module?;
                       var expr : ExprCallMacro?) : ExpressionPtr {
        let modName = mod == null ? "anon" : string(mod.name)
        let path_key = "{modName}:{expr.at.line:d}:{expr.at.column:d}"
        var rewritten = new ExprCall(at = expr.at, name := kind_name)
        var pathArg = new ExprConstString(at = expr.at, value := path_key)
        rewritten.arguments |> push(pathArg)
        for (a in expr.arguments) {
            rewritten.arguments |> push(clone_expression(a))
        }
        return <- rewritten
    }
}

[function_macro(name = "drawlist_prim")]
class DrawlistPrimFunctionMacro : AstFunctionAnnotation {
    //! ``[drawlist_prim]`` — registers ``def fn(var dl, ...)`` as a drawlist
    //! primitive. Injects ``widget_ident`` at position 0 and a per-kind
    //! call_macro that prepends a synthesized ``<mod>:<line>:<col>`` path key.
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        if (empty(func.arguments)) {
            errors := "[drawlist_prim] requires at least one parameter (the drawlist pointer)"
            return false
        }
        let kind = string(func.name)
        func.flags.generated = true
        var widthIdentVar = new Variable(at = func.at,
            name := "widget_ident",
            _type <- new TypeDecl(baseType = Type.tString, at = func.at))
        widthIdentVar.flags.generated = true
        func.arguments |> emplace(widthIdentVar, 0)
        var inst = new DrawlistPrimCallMacro(kind_name = kind)
        compiling_module() |> add_call_macro(make_call_macro(kind, inst))
        return true
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
    func.flags.generated = true
    // Inject widget_ident : string at index 1 (between state and rest).
    // The user's body code references `widget_ident` literally when
    // calling widget_finalize / container_finalize — this param makes it in scope.
    var widthIdentVar = new Variable(at = func.at,
        name := "widget_ident",
        _type <- new TypeDecl(baseType = Type.tString, at = func.at))
    widthIdentVar.flags.generated = true
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
        render_fn_name = kind,
        is_container = is_container)
    // Stash the widget def's user-facing args (positions 2..N, after the
    // injected widget_ident at position 1). The indexed-form wrapper
    // generator mirrors this signature for each (kind, IDENT) pair so the
    // user's call site forwards args unchanged into the underlying widget.
    let userArgN = length(func.arguments) - 2
    if (userArgN > 0) {
        inst.render_fn_args |> reserve(userArgN)
    }
    for (i in range(2, length(func.arguments))) {
        inst.render_fn_args |> push(func.arguments[i])
    }
    // Stash the underlying FunctionPtr (long-lived; lives in the widget's
    // module). The indexed-form wrapper reads .arguments and .result at
    // visit time, sidestepping the lifetime issue we saw when caching a
    // cloned TypeDecl on the WidgetCallMacro instance (the clone aliased
    // to whatever the gc heap reused that slot for, giving the wrapper
    // wrong return types like `double`/`tuple<>`/`GroupState`).
    inst.render_fn = func
    compiling_module() |> add_call_macro(make_call_macro(kind, inst))
    return true
}

class WidgetCallMacro : AstCallMacro {
    kind_name : string
    state_type_name : string
    state_struct : Structure const?
    render_fn_name : string
    is_container : bool
    render_fn_args : array<VariablePtr>
    render_fn : FunctionPtr

    def override canVisitArgument(expr : ExprCallMacro?; argIndex : int) : bool {
        // The first argument is the IDENT (which doesn't yet exist as a
        // global); telling the typer not to pre-resolve it lets us see the
        // raw ExprVar in visit(), parse the dotted-flag chain, emit the
        // global, and rewrite. Other args resolve normally before we see them.
        return argIndex != 0
    }

    // Auto-gen state-global identifier for no-ident call forms. `__widget_`
    // prefix + line + column packs a unique-within-module name into a legal
    // daslang identifier. Two widget calls on the same line use different
    // columns so they don't collide.
    def private synth_bare_name(at : LineInfo) : string {
        return "__widget_{at.line:d}_{at.column:d}"
    }

    // Auto-gen telemetry path key: `<module>:<line>:<column>`. Surfaces in
    // imgui_snapshot under `<window>/<this>`. Shifts on edits — explicit
    // idents remain the right answer when path stability matters
    // (interactive widgets driven by test commands).
    def private synth_path_key(mod : Module?; at : LineInfo) : string {
        let modName = mod == null ? "anon" : string(mod.name)
        return "{modName}:{at.line:d}:{at.column:d}"
    }

    // Positional-string sugar (`text("hello")` etc.) is only valid when the
    // user-facing signature is exactly a single `string` argument — i.e. the
    // narrative-text family. Signature after widget_ident injection:
    // (state; widget_ident; text : string) — length 3, last arg is string.
    def private accepts_positional_string() : bool {
        return false if (render_fn == null || length(render_fn.arguments) != 3)
        let argT = render_fn.arguments[2]._type
        return false if (argT == null)
        return argT.baseType == Type.tString
    }

    // Bare no-arg form (`spacing()`, `same_line()`) is valid when every
    // user-facing arg (positions 2..N after state + widget_ident) has a
    // default initializer — `Variable.init != null`.
    def private all_user_args_defaulted() : bool {
        return false if (render_fn == null)
        for (i in range(2, length(render_fn.arguments))) {
            return false if (render_fn.arguments[i].init == null)
        }
        return true
    }

    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        // Four call forms:
        //   1. EXPLICIT      kind(IDENT, (...))              — leading ident drives state global
        //   2. AUTO-GEN      kind((...))                     — first arg is a named-tuple; ident synthesized from source location
        //   3. POSITIONAL    kind("string") / kind("{n}")    — single-string (or string_builder) sugar for narrative-text family; rewrites to AUTO-GEN
        //   4. BARE          kind()                          — zero args; only valid when the widget signature has no user args (state + widget_ident only). Ident synthesized.
        // When the user wants to read state (`.value`/`.click_count`), they
        // must use form 1; the synthesized name in forms 2/3/4 is internal and
        // shifts on edits. Documented as "want state, name state".
        var bareName : string
        var widgetIdentOverride : string
        var rawName : string
        var flagsReversed : array<string>
        var indexExpr : ExpressionPtr
        var firstUserArg = 1
        if (empty(expr.arguments)) {
            // Form 4: bare no-arg. Valid when every user arg (positions 2..N)
            // has a default initializer — stateless layout primitives
            // (separator/spacing/new_line/align_text_to_frame_padding) have
            // none; same_line / indent / unindent have all-defaulted args.
            if (render_fn == null || !all_user_args_defaulted()) {
                macro_error(prog, expr.at, "{kind_name}(...): missing widget body — pass `(named=arg, …)` or, for narrative widgets, a single string literal")
                return <- default<ExpressionPtr>
            }
            bareName = synth_bare_name(expr.at)
            widgetIdentOverride = synth_path_key(mod, expr.at)
            firstUserArg = 0
        } else {
            let head = expr.arguments[0]
            if (head is ExprConstString || head is ExprStringBuilder) {
                // Form 3: positional-string sugar. Accepts a string literal
                // (`text("foo")`) or an interpolated string_builder
                // (`text("count: {n}")`). Valid only when the widget signature
                // is exactly (state; widget_ident; text : string).
                if (!accepts_positional_string()) {
                    macro_error(prog, head.at, "{kind_name}: positional-string form `{kind_name}(\"…\")` is only valid for single-string narrative widgets (text/text_unformatted/text_wrapped/text_disabled/bullet_text/separator_text). Use the named-tuple form `{kind_name}((…))` instead.")
                    return <- default<ExpressionPtr>
                }
                bareName = synth_bare_name(expr.at)
                widgetIdentOverride = synth_path_key(mod, expr.at)
                firstUserArg = 0
                // Rewrite expr.arguments[0] from the bare string/builder to a
                // synthesized named-tuple `(text = <head>)` so the destructure
                // loop below emits a single positional `text` arg into the
                // rewritten call.
                var synth = new ExprMakeTuple(at = head.at)
                synth.recordNames.resize(1)
                synth.recordNames[0] := "text"
                synth.values |> push(clone_expression(head))
                expr.arguments[0] = synth
            } elif (head is ExprMakeTuple && (head as ExprMakeTuple) != null
                    && length((head as ExprMakeTuple).recordNames) == length((head as ExprMakeTuple).values)
                    && !empty((head as ExprMakeTuple).recordNames)) {
                // STYLE001 — verbose `kind((field="literal"))` where positional `kind("literal")` works.
                // Three gates, ALL must match:
                //   1. Single arg, single named-tuple field (no other call args).
                //   2. The lone field's value is a string literal or string-builder
                //      — positional sugar at line 222 only accepts those, so an ExprVar
                //      arg has NO positional alternative (would silently become Form 1
                //      and treat the var as the widget IDENT).
                //   3. Wrapper accepts positional-string form AND the field name matches
                //      the wrapper's first user param.
                //   4. `_allow_imgui_legacy = true` is NOT set on the consumer file.
                let mtCheck = head as ExprMakeTuple
                if (length(expr.arguments) == 1 && length(mtCheck.recordNames) == 1
                        && (mtCheck.values[0] is ExprConstString || mtCheck.values[0] is ExprStringBuilder)
                        && accepts_positional_string()) {
                    let firstParamName = string(render_fn.arguments[2].name)
                    let tupleFieldName = string(mtCheck.recordNames[0])
                    let opted_out = prog._options |> find_arg("_allow_imgui_legacy") ?as tBool ?? false
                    if (firstParamName == tupleFieldName && !opted_out) {
                        macro_error(prog, expr.at,
                            "STYLE001: prefer positional form `{kind_name}(\"...\")` over verbose named-tuple `{kind_name}(({tupleFieldName}=...))`. Per-file opt-out: `options _allow_imgui_legacy = true`")
                        return <- default<ExpressionPtr>
                    }
                }
                // Form 2: auto-gen ident from source location. The first arg is a
                // named-tuple — user did not supply an ident.
                bareName = synth_bare_name(expr.at)
                widgetIdentOverride = synth_path_key(mod, expr.at)
                firstUserArg = 0
            }
        }
        // Form 1: explicit ident — leading-arg parser. Skipped when bareName
        // is already populated by the auto-gen / positional-string branches.
        if (empty(bareName)) {
            var cursor : Expression const? = expr.arguments[0]
            if (cursor is ExprAt) {
                let ea = cursor as ExprAt
                // ExprSafeAt (?[]) is a subclass of ExprAt in C++; reject explicitly.
                if (cursor.__rtti != "ExprAt") {
                    macro_error(prog, expr.at, "{kind_name}(IDENT[k]): safe subscript ?[k] not supported on indexed widgets")
                    return <- default<ExpressionPtr>
                }
                indexExpr = clone_expression(ea.index)
                cursor = ea.subexpr
            }
            while (cursor is ExprField) {
                let fld = cursor as ExprField
                flagsReversed |> push(string(fld.name))
                cursor = fld.value
            }
            if (cursor is ExprVar) {
                bareName = string((cursor as ExprVar).name)
            } else {
                macro_error(prog, expr.at, "{kind_name}(...): first argument must be an identifier, named-tuple `(…)`, dotted-flag `IDENT.FLAG[.FLAG…]`, indexed `IDENT[key]`, or (for narrative widgets) a string literal; got {describe(expr.arguments[0])}")
                return <- default<ExpressionPtr>
            }
            if (indexExpr != null && !empty(flagsReversed)) {
                macro_error(prog, expr.at, "{kind_name}({bareName}[k]): dotted flags (.PUBLIC/.NOTLIVE) not supported on indexed form — declare the table global with required annotations directly")
                return <- default<ExpressionPtr>
            }
            // Indexed (table-form) widget: distinct path from single-global —
            // table global is user-declared, wrapper helper is generated per
            // (kind, IDENT), no init=/bounds= sugar (use [init] for imperative
            // pre-population). Returns the wrapper-call rewrite.
            return <- emit_indexed_call(prog, mod, expr, bareName, indexExpr) if (indexExpr != null)
            // Reconstruct rawName for error messages (source order).
            rawName = build_string() $(var w) {
                w |> write(bareName)
                for (i in range(0, length(flagsReversed))) {
                    w |> write(".")
                    w |> write(flagsReversed[length(flagsReversed) - 1 - i])
                }
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
        // Extract init-mapped named-tuple args (e.g. `init=0.5f`, `range=(0,1)`)
        // BEFORE emit / destructure. These flow into the state global's
        // initializer; the call itself never sees them. Collected into
        // initFieldNames/Exprs (parallel arrays so insertion order is
        // preserved — matches source order at the call site).
        var initFieldNames : array<string>
        var initFieldExprs : array<ExpressionPtr>
        // §4.8 per-call overrides — string literals (must be ExprConstString)
        // pulled out of the named-tuple args. `id=` wraps the render call in
        // PushID/PopID (ImGui hash override only). `path=` replaces bareName
        // as the widget_ident second arg (both telemetry path AND ImGui hash
        // change, since widget_prelude does PushID(widget_ident) inside).
        var idOverride : string
        var idOverridePresent = false
        var pathOverride : string
        var pathOverridePresent = false
        for (i in range(firstUserArg, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (j in range(length(mt.recordNames))) {
                        let recordName = string(mt.recordNames[j])
                        let fieldName = init_arg_to_field(recordName)
                        if (!empty(fieldName)) {
                            initFieldNames |> push(fieldName)
                            initFieldExprs |> push(clone_expression(mt.values[j]))
                        } elif (recordName == "id") {
                            if (!(mt.values[j] is ExprConstString)) {
                                macro_error(prog, mt.values[j].at,
                                            "{kind_name}({bareName}, id=...): `id=` must be a string literal")
                                return <- default<ExpressionPtr>
                            }
                            idOverride = string((mt.values[j] as ExprConstString).value)
                            idOverridePresent = true
                        } elif (recordName == "path") {
                            if (!(mt.values[j] is ExprConstString)) {
                                macro_error(prog, mt.values[j].at,
                                            "{kind_name}({bareName}, path=...): `path=` must be a string literal")
                                return <- default<ExpressionPtr>
                            }
                            pathOverride = string((mt.values[j] as ExprConstString).value)
                            pathOverridePresent = true
                        }
                    }
                }
            }
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
            initCall.makeStructFlags.useInitializer = true
            // Seed named-init fields (init=/range= sugar) into the initializer.
            // `useInitializer=true` keeps struct defaults firing for un-seeded
            // fields; field LineInfo points at the call site so a wrong field
            // (e.g. `range=` on a button) reports against the user's arg.
            if (!empty(initFieldNames)) {
                var mkS = new MakeStruct(uninitialized)
                for (j in range(length(initFieldNames))) {
                    var mkF = new MakeFieldDecl(at = expr.at,
                                                name := initFieldNames[j],
                                                value = initFieldExprs[j])
                    emplace_new(*mkS, mkF)
                }
                emplace(initCall.structs, mkS)
            }
            var v = new Variable(at = expr.at,
                name := bareName,
                _type <- typeRef,
                init = initCall)
            v.flags.generated = true
            if (!flagPublic) {
                v.flags.private_variable = true
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
                    @() : void? {
                        return unsafe(addr($i(identLit)))
                    },
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
        // widgetIdent precedence: user `path=` override → auto-gen
        // `mod:line:col` synthesized at the top → fallback to bareName.
        var widgetIdent = bareName
        if (!empty(widgetIdentOverride)) {
            widgetIdent = widgetIdentOverride
        }
        if (pathOverridePresent) {
            widgetIdent = pathOverride
        }
        var newCall = new ExprCall(at = expr.at, name := render_fn_name)
        newCall.arguments |> push(new ExprVar(at = expr.at, name := bareName))
        newCall.arguments |> push(new ExprConstString(at = expr.at, value := widgetIdent))
        for (i in range(firstUserArg, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (j in range(length(mt.recordNames))) {
                        let recordName = string(mt.recordNames[j])
                        // Skip init-mapped names (consumed by the global's
                        // initializer above) and id=/path= (consumed at
                        // wrap/widget_ident-substitution time).
                        continue if (!empty(init_arg_to_field(recordName)) ||
                                     recordName == "id" ||
                                     recordName == "path")
                        newCall.arguments |> push(clone_expression(mt.values[j]))
                    }
                    continue
                }
            }
            newCall.arguments |> push(clone_expression(a))
        }
        if (idOverridePresent) {
            // Wrap in a void block: PushID(idLit); call(); PopID(). Because
            // the block evaluates to void, capturing the widget's return
            // value while id= is in play won't compile — that's intentional
            // for first cut (rare combo; users can use `with_id(idLit) { let
            // r = button(...) }` for the bool-return form). Same wrapping
            // shape mirrors `with_id` exactly.
            let idLit = idOverride
            return qmacro_block() {
                PushID($v(idLit))
                $e(newCall)
                PopID()
            }
        }
        return <- newCall
    }

    def private emit_indexed_call(prog : ProgramPtr; mod : Module?;
                                  var expr : ExprCallMacro?;
                                  bareName : string;
                                  var indexExpr : ExpressionPtr) : ExpressionPtr {
        let tableVar = find_variable(mod, bareName)
        if (tableVar == null) {
            let msg = "{kind_name}({bareName}[k]): table global '{bareName}' is not declared at module scope. Declare it as:  variable private {bareName} : table<int; {state_type_name}>  (or table<string; ...> for string keys)."
            macro_error(prog, expr.at, msg)
            return <- default<ExpressionPtr>
        }
        let tabType = tableVar._type
        if (tabType == null || tabType.baseType != Type.tTable) {
            macro_error(prog, expr.at,
                "{kind_name}({bareName}[k]): '{bareName}' is not a table (got {describe(tabType)}). Expected table<K; {state_type_name}>.")
            return <- default<ExpressionPtr>
        }
        if (tabType.secondType == null || unsafe(reinterpret<Structure?>(tabType.secondType.structType)) != unsafe(reinterpret<Structure?>(state_struct))) {
            macro_error(prog, expr.at,
                "{kind_name}({bareName}[k]): table value type ({describe(tabType.secondType)}) does not match expected state {state_type_name}.")
            return <- default<ExpressionPtr>
        }
        // Reject init=/bounds= sugar — first-touch initialization for indexed
        // widgets is via [init] function (imperative), not call-site named args.
        for (i in range(1, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (j in range(length(mt.recordNames))) {
                        let recordName = string(mt.recordNames[j])
                        if (!empty(init_arg_to_field(recordName))) {
                            let msg = "{kind_name}({bareName}[k]): named-init sugar ({recordName}=) not supported on indexed form. Pre-populate {bareName} in an [init] function (e.g. `{bareName}[i].bounds = (0,1); {bareName}[i].value = 0.5f`)."
                            macro_error(prog, expr.at, msg)
                            return <- default<ExpressionPtr>
                        }
                        if (recordName == "id" || recordName == "path") {
                            let msg = "{kind_name}({bareName}[k], {recordName}=...): per-call {recordName}= override not supported on indexed form (each [k] already gets its own ImGui hash and path key). Wrap the indexed call in `with_id(s)` for an extra scope segment instead."
                            macro_error(prog, expr.at, msg)
                            return <- default<ExpressionPtr>
                        }
                    }
                }
            }
        }
        let wrapperName = "$imgui$indexed${kind_name}${bareName}"
        let moduleName = string(mod.name)
        let bareNameLit = bareName
        let kindLit = kind_name
        // Emit the wrapper helper once per (kind, IDENT). find_unique_function
        // probes the user module before add_function fires; re-running visit()
        // for the same wrapper (e.g. a second call site) is a no-op.
        if (find_unique_function(mod, wrapperName, true) == null) {
            var wrapperArgs : array<VariablePtr>
            for (a in render_fn_args) {
                wrapperArgs |> emplace_new <| clone_variable(a)
            }
            // Forward call: <kind>(<bareName>[k], bare, ...args by name)
            var callArgs <- array<ExpressionPtr>(
                qmacro($i(bareNameLit)[$i("k")]),
                qmacro($i("bare")))
            callArgs |> reserve(2 + length(render_fn_args))
            for (a in render_fn_args) {
                let argName = string(a.name)
                callArgs |> push <| qmacro($i(argName))
            }
            let keyType = clone_type(tabType.firstType)
            let retType = clone_type(render_fn.result)
            var bodyStmts : array<ExpressionPtr>
            // bare = "<bareName>[<k>]" — runtime interp builds the path component
            bodyStmts |> push <| qmacro_expr(${
                let bare = "{$v(bareNameLit)}[{k}]"
            })
            // Do NOT push to container_path here even for containers — the
            // called [container]'s own macro-injected `container_path_push
            // (widget_ident)` does that with the same `bare` value. A wrapper
            // push would double-nest the path (`.../DYN_TAB[0]/DYN_TAB[0]`).
            // path = container-aware key (matches what widget_finalize computes)
            bodyStmts |> push <| qmacro_expr(${
                let path = imgui_boost_runtime::widget_path_key(bare)
            })
            // First-touch / post-reload register. Both lambdas capture the
            // key by value; the address getter and serializer guard with
            // ``key_exists`` and re-resolve ``TABLE[k]`` on every invoke, so
            // rehashing or erase+re-add never desyncs state.
            bodyStmts |> push <| qmacro_expr(${
                if (!imgui_boost_runtime::widget_registered(path)) {
                    unsafe {
                        let addr_getter <- @ capture(= k) () : void ? {
                            return null if (!key_exists($i(bareNameLit), k))
                            return unsafe(addr($i(bareNameLit)[k]))
                        }
                        let ser <- @ capture(= k) () : JsonValue ? {
                            return null if (!key_exists($i(bareNameLit), k))
                            return JV($i(bareNameLit)[k])
                        }
                        imgui_boost_runtime::register_widget(
                            $v(moduleName), path, $v(kindLit),
                            addr_getter, ser)
                    }
                }
            })
            // Final call. The called [container]'s own finally block pops
            // its container_path_push, so no wrapper-side pop is needed.
            if (retType.baseType == Type.tVoid) {
                bodyStmts |> push <| qmacro_expr(${
                    $c(kindLit)($a(callArgs))
                })
            } else {
                bodyStmts |> push <| qmacro_expr(${
                    return $c(kindLit)($a(callArgs))
                })
            }
            var fn = qmacro_function(wrapperName) $(k : $t(keyType); $a(wrapperArgs)) : $t(retType) {
                $b(bodyStmts)
            }
            fn.flags.generated = true
            fn.flags.privateFunction = true
            fn.body |> force_at(expr.at)
            if (!(mod |> add_function(fn))) {
                macro_error(prog, expr.at,
                    "{kind_name}({bareName}[k]): failed to add indexed wrapper function '{wrapperName}'")
                return <- default<ExpressionPtr>
            }
        }
        // Rewrite call: wrapperName(indexExpr, ...remaining args)
        var newCall = new ExprCall(at = expr.at, name := wrapperName)
        newCall.arguments |> push(indexExpr)
        for (i in range(1, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (j in range(length(mt.recordNames))) {
                        newCall.arguments |> push(clone_expression(mt.values[j]))
                    }
                    continue
                }
            }
            newCall.arguments |> push(clone_expression(a))
        }
        return <- newCall
    }
}

// `[edit_widget]` annotation — external-pointer sibling of `[widget]`. The
// annotated function takes (ptr : T?, ...named args...). No state struct,
// no auto-emit, no init=/bounds= sugar. The macro extracts the call-site
// `id="..."` (required, string literal) and rewrites to a positional call;
// the renderer captures `ptr` in serializer/dispatcher closures so snapshot
// reads dereference `*ptr` live. Caller picks `safe_addr(local)` vs
// `unsafe(addr(struct.field))` and owns the pointee lifetime.

[function_macro(name = "edit_widget")]
class EditWidgetFunctionMacro : AstFunctionAnnotation {
    //! ``[edit_widget]`` annotation — registers an external-pointer widget. First parameter is the user-owned pointer (``T?``); macro injects ``widget_ident : string`` at index 1 and installs a call_macro that requires an explicit ``id="..."`` literal at the call site.
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        return apply_edit_widget_or_container(func, errors, false)
    }
}

[function_macro(name = "edit_container")]
class EditContainerFunctionMacro : AstFunctionAnnotation {
    //! ``[edit_container]`` annotation — block-arg sibling of ``[edit_widget]``. First parameter is the user-owned pointer (``T?``); last parameter must be ``blk : block``. Macro injects ``widget_ident : string`` at index 1 and wraps the body with ``container_path_push``/``pop`` so leaves rendered inside ``invoke(blk)`` nest under the container's path key. Same ``id="..."`` literal requirement as ``[edit_widget]``.
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        if (empty(func.arguments) || func.arguments[length(func.arguments) - 1]._type == null
            || func.arguments[length(func.arguments) - 1]._type.baseType != Type.tBlock) {
            errors := "[edit_container] requires the last parameter to be `blk : block`"
            return false
        }
        return apply_edit_widget_or_container(func, errors, true)
    }
}

def private apply_edit_widget_or_container(var func : FunctionPtr; var errors : das_string;
                                           is_container : bool) : bool {
    if (empty(func.arguments)) {
        errors := "[edit_widget]/[edit_container] requires at least one parameter (ptr)"
        return false
    }
    let ptrArg = func.arguments[0]
    if (ptrArg._type == null || ptrArg._type.baseType != Type.tPointer) {
        errors := "[edit_widget]/[edit_container] first parameter must be a pointer (e.g. `float?`, `int?`, `bool?`)"
        return false
    }
    let kind = string(func.name)
    func.flags.generated = true
    // Inject widget_ident : string at index 1 (between ptr and the rest).
    // Mirrors the [widget] macro injection so the user body can reference
    // `widget_ident` literally when calling widget_finalize / edit_finalize.
    var widthIdentVar = new Variable(at = func.at,
        name := "widget_ident",
        _type <- new TypeDecl(baseType = Type.tString, at = func.at))
    widthIdentVar.flags.generated = true
    func.arguments |> emplace(widthIdentVar, 1)
    // Wrap the body: prepend widget_prelude(widget_ident). For containers
    // also push the container path before the user body runs (so leaves
    // emitted inside `invoke(blk)` nest under our ident); matching pop
    // lives in body.finalList so it always runs on normal return.
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
    var inst = new EditExternalCallMacro(
        kind_name = kind,
        render_fn = func)
    let userArgN = length(func.arguments) - 2
    if (userArgN > 0) {
        inst.render_fn_args |> reserve(userArgN)
    }
    for (i in range(2, length(func.arguments))) {
        inst.render_fn_args |> push(func.arguments[i])
    }
    compiling_module() |> add_call_macro(make_call_macro(kind, inst))
    return true
}

class EditExternalCallMacro : AstCallMacro {
    //! Call macro installed by ``[edit_widget]``. Recognizes ``edit_kind(ptr, (id="...", ...))``, requires an explicit ``id=`` string literal, destructures the rest of the named-tuple to positional args (source order — match parameter order, like ``WidgetCallMacro``), and rewrites to a direct call into the renderer.
    //! Name of the ``[edit_widget]``-decorated function — used as the rewritten call's target and in macro_error messages.
    //! Underlying ``[edit_widget]`` function pointer; lives in the user module and is read at visit time.
    //! User-facing args (positions 2..N after ``ptr`` + injected ``widget_ident``); cloned from ``render_fn`` so the wrapper preserves names/defaults.
    kind_name : string
    render_fn : FunctionPtr
    render_fn_args : array<VariablePtr>

    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        if (empty(expr.arguments)) {
            macro_error(prog, expr.at, "{kind_name}(ptr, (id=\"...\", ...)): missing pointer argument")
            return <- default<ExpressionPtr>
        }
        // Extract id= from named-tuple args (must be present; string literal).
        var idLit : string
        var idPresent = false
        for (i in range(1, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (j in range(length(mt.recordNames))) {
                        if (mt.recordNames[j] == "id") {
                            if (!(mt.values[j] is ExprConstString)) {
                                macro_error(prog, mt.values[j].at,
                                            "{kind_name}(..., id=...): `id=` must be a string literal")
                                return <- default<ExpressionPtr>
                            }
                            idLit = string((mt.values[j] as ExprConstString).value)
                            idPresent = true
                        }
                    }
                }
            }
        }
        if (!idPresent) {
            macro_error(prog, expr.at,
                "{kind_name}(ptr, (id=\"...\", ...)): external-pointer widgets require an explicit `id=\"...\"` for the telemetry path. No auto-generation — pick a stable unique identifier.")
            return <- default<ExpressionPtr>
        }
        if (empty(idLit)) {
            macro_error(prog, expr.at, "{kind_name}: `id=` must not be empty")
            return <- default<ExpressionPtr>
        }
        // Rewrite to positional: kind_name(ptr, "<idLit>", ...named args destructured).
        var newCall = new ExprCall(at = expr.at, name := kind_name)
        newCall.arguments |> push(clone_expression(expr.arguments[0]))
        newCall.arguments |> push(new ExprConstString(at = expr.at, value := idLit))
        for (i in range(1, length(expr.arguments))) {
            let a = expr.arguments[i]
            if (a is ExprMakeTuple) {
                let mt = a as ExprMakeTuple
                if (length(mt.recordNames) == length(mt.values) && !empty(mt.recordNames)) {
                    for (j in range(length(mt.recordNames))) {
                        continue if (mt.recordNames[j] == "id")
                        newCall.arguments |> push(clone_expression(mt.values[j]))
                    }
                    continue
                }
            }
            newCall.arguments |> push(clone_expression(a))
        }
        return <- newCall
    }
}
