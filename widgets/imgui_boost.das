options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_boost_v2 shared

require imgui public
require imgui/imgui_boost_runtime public
require daslib/ast
require daslib/ast_boost
require daslib/templates_boost

//! Phase 0a — `define_widget` core (function-annotation form).
//!
//! Mark a function `[widget]` to register it as a custom imgui widget kind.
//! The function name becomes the kind name; the first parameter must be the
//! state struct (passed `var`). The macro:
//!   - inserts a leading `name : string` parameter (the daslang identifier
//!     used at the call site)
//!   - wraps the body with `widget_prelude(name)` ... `widget_postlude(name, snap)`
//!   - renames the function to `__widget_render_<kind>` and marks it private
//!   - dynamically registers a per-kind call macro that rewrites
//!     `kind(IDENT, args...)` to `__widget_render_<kind>("IDENT", IDENT, args...)`
//!     and emits the IDENT global at module scope on first use.

[function_macro(name = "widget")]
class WidgetFunctionMacro : AstFunctionAnnotation {
    def override apply(var func : FunctionPtr; var group : ModuleGroup;
                       args : AnnotationArgumentList; var errors : das_string) : bool {
        if (length(func.arguments) < 1) {
            return false
        }
        let kind = string(func.name)
        let stateArg = func.arguments[0]
        let stateTypeName = describe(stateArg._type)
        // The function stays public (callable as `<kind>(state, args...)`).
        // The call_macro intercepts the user's `<kind>(IDENT, ...)` shape and
        // rewrites it to `<kind>(IDENT_global, ...)`, which the typer then
        // resolves to this function via normal lookup.
        func.flags |= FunctionFlags.generated
        // Wrap the body: prepend prelude, append postlude to finalList. Phase
        // 0a uses the second parameter's name (conventionally `text`) as the
        // registry key — same as ImGui's label-based GetID. Phase 0a.1 will
        // thread the call-site IDENT through so the registry key matches the
        // daslang identifier (cleaner for telemetry).
        if (length(func.arguments) >= 2) {
            let labelParamName = string(func.arguments[1].name)
            var fblk = new ExprBlock(at = func.body.at)
            fblk.list |> push(qmacro(widget_prelude($i(labelParamName))))
            fblk.list |> push <| qmacro_expr(${
                var widget_snap : WidgetSnapshot
            })
            fblk.list |> push <| qmacro_expr(${
                widget_snap.kind = $v(kind)
            })
            let oldBody = func.body as ExprBlock
            for (el in oldBody.list) {
                fblk.list |> push(clone_expression(el))
            }
            for (ef in oldBody.finalList) {
                fblk.finalList |> push(clone_expression(ef))
            }
            fblk.finalList |> push(qmacro(widget_postlude($i(labelParamName), widget_snap)))
            func.body = fblk
        }
        // Register the per-kind call macro instance. Duplicate-name collisions
        // (e.g. two `[widget] def slider(...)` overloads on different state
        // types) trigger a C++-side panic with a clean error from add_call_macro
        // ("can't add call macro <name> to module <mod>"). Phase 0a sticks to
        // distinct kind names per state type (button, slider, slider_int);
        // overload dispatch is deferred. Note: find_call_macro can't be used
        // for a soft pre-check — its C++ binding crashes when the name is
        // absent. Daslang issue worth reporting separately.
        var inst = new WidgetCallMacro(
            kind_name = kind,
            state_type_name = stateTypeName,
            render_fn_name = kind)
        compiling_module() |> add_call_macro(make_call_macro(kind, inst))
        return true
    }
}

//! Per-kind call dispatcher. One instance per `[widget]` declaration; created
//! by `WidgetFunctionMacro` and registered via `add_call_macro`. Intercepts
//! every `<kind>(IDENT, ...)` call and:
//!   1. Parses the dotted identifier (`SAVE_BTN.PUBLIC` etc.) into name + flags
//!   2. Ensures the module-scope state global exists (idempotent — re-uses
//!      the existing decl if already there)
//!   3. Rewrites the call to `__widget_render_<kind>("IDENT", IDENT, args...)`

class WidgetCallMacro : AstCallMacro {
    kind_name : string
    state_type_name : string
    render_fn_name : string

    def override canVisitArgument(expr : ExprCallMacro?; argIndex : int) : bool {
        // The first argument is the IDENT (which doesn't yet exist as a
        // global); telling the typer not to pre-resolve it lets us see the
        // raw ExprVar in visit(), emit the global, and rewrite. Other args
        // are resolved normally before we see them.
        return argIndex != 0
    }

    def override visit(prog : ProgramPtr; mod : Module?; var expr : ExprCallMacro?) : ExpressionPtr {
        if (length(expr.arguments) < 1) {
            macro_error(prog, expr.at, "{kind_name}(IDENT, ...): missing widget identifier")
            return <- default<ExpressionPtr>
        }

        let identExpr = expr.arguments[0]
        if (!(identExpr is ExprVar)) {
            macro_error(prog, expr.at, "{kind_name}(IDENT, ...): first argument must be an identifier (got {describe(identExpr)})")
            return <- default<ExpressionPtr>
        }
        let identName = string((identExpr as ExprVar).name)

        // Idempotently ensure the module global exists. The check uses the
        // module the call site is in (mod), not the macro's own module.
        var existing = false
        mod |> for_each_global() $(g) {
            if (g.name == identName) {
                existing = true
            }
        }
        if (!existing) {
            var v = new Variable(at = expr.at,
                name := identName,
                _type <- new TypeDecl(baseType = Type.alias, alias := state_type_name, at = expr.at))
            v.flags |= VariableFlags.generated | VariableFlags.private_variable
            // The global is intentionally NOT tagged @live. Per Chunk A's
            // per-field machinery, leaving the global unmarked lets each
            // state struct's @live fields (e.g. click_count) preserve
            // independently while the per-frame transient fields (bbox/hover/
            // pending_click) reset on every reload — exactly what §9.1 wants.
            mod |> add_variable(v)
        }

        // Rewrite to `<kind>(IDENT, args...)`. The function lives in the
        // imgui_widgets_builtin module (shared, public). The same call_macro
        // that brought us here intercepts only top-level `<kind>(...)` calls
        // at the parser level — once we replace the ExprCallMacro with a
        // regular ExprCall, the typer resolves it via normal lookup and finds
        // the underlying function.
        var newCall = new ExprCall(at = expr.at, name := render_fn_name)
        newCall.arguments |> push(new ExprVar(at = expr.at, name := identName))
        for (i in range(1, length(expr.arguments))) {
            newCall.arguments |> push(clone_expression(expr.arguments[i]))
        }
        return <- newCall
    }
}
