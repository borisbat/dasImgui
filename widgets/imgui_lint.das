options gen2
options indenting = 4
options strict_smart_pointers = true

module imgui_lint shared private

//! dasImgui lint pass — `_no_imgui_legacy`.
//!
//! Opt-in compile-time pass that forbids legacy ImGui access from consumer
//! files. Enabled by ``options _no_imgui_legacy = true``; off otherwise.
//!
//! Codes:
//!   IMGUI001 — any call into the dead v1 `imgui_boost` module
//!   IMGUI002 — any raw `imgui::*` call not on the allow-list
//!
//! The allow-list (``ALLOWED_IMGUI`` below) is the curated set of raw
//! bindings that v2 deliberately doesn't wrap (frame lifecycle, IO/state
//! queries, demo windows, pre-window state). Everything else must go
//! through a [widget] / [container] / with_* wrapper in widgets/.
//!
//! Scoping: walks ``prog.getThisModule`` only, so the lint runs on the
//! consumer file and skips the transitively-required boost modules
//! (which legitimately call raw ``imgui::*`` because that's the whole
//! point of being the wrapper).

require daslib/ast_boost
require strings

let private ALLOWED_IMGUI : table<string> <- {
    // Context / frame lifecycle
    "CreateContext", "DestroyContext", "GetCurrentContext", "SetCurrentContext",
    "NewFrame", "EndFrame", "Render", "GetDrawData",
    // IO / per-item state queries (post-widget probes — no v2 host needed)
    "GetIO", "GetStyle",
    "IsItemHovered", "IsItemActive", "IsItemClicked", "IsItemFocused",
    "IsItemActivated", "IsItemDeactivated", "IsItemDeactivatedAfterEdit",
    "IsItemToggledOpen", "IsItemVisible", "IsItemEdited",
    "IsAnyItemHovered", "IsAnyItemActive", "IsAnyItemFocused",
    // Mouse / keyboard state queries — pure reads, no widget host.
    "GetMousePos", "GetMousePosOnOpeningCurrentPopup",
    "IsMouseDown", "IsMouseClicked", "IsMouseReleased", "IsMouseDoubleClicked",
    "IsMouseHoveringRect", "IsAnyMouseDown",
    "GetMouseDragDelta", "ResetMouseDragDelta", "IsMouseDragging",
    "IsKeyDown", "IsKeyPressed", "IsKeyReleased",
    "GetKeyName", "GetTime", "GetFrameCount",
    // Cursor / layout queries (read-only)
    "GetCursorPos", "GetCursorPosX", "GetCursorPosY",
    "GetCursorScreenPos", "GetCursorStartPos",
    "GetContentRegionAvail",
    "GetWindowSize", "GetWindowPos", "GetWindowWidth", "GetWindowHeight",
    "GetItemRectMin", "GetItemRectMax", "GetItemRectSize",
    "CalcTextSize", "CalcItemWidth",
    // Font / color helpers (read-only)
    "GetFontSize",
    "GetTextLineHeight", "GetTextLineHeightWithSpacing",
    "GetFrameHeight", "GetFrameHeightWithSpacing",
    "GetStyleColorVec4", "GetColorU32",
    // Demo / debug entry points (built-in windows we deliberately surface as-is)
    "ShowDemoWindow", "ShowMetricsWindow", "ShowDebugLogWindow",
    "ShowIDStackToolWindow", "ShowAboutWindow",
    "ShowStyleEditor", "ShowFontSelector", "ShowStyleSelector",
    "ShowUserGuide",
    // Pre-window state — kept allowed; candidates for future v2-arg absorption.
    "SetNextWindowPos", "SetNextWindowSize", "SetNextWindowSizeConstraints",
    "SetNextWindowContentSize", "SetNextWindowCollapsed", "SetNextWindowFocus",
    "SetNextWindowBgAlpha", "SetNextWindowViewport",
    "SetNextItemWidth", "SetNextItemOpen",
    "SetKeyboardFocusHere", "SetItemDefaultFocus", "SetScrollHereX", "SetScrollHereY",
    "SetScrollX", "SetScrollY", "GetScrollX", "GetScrollY",
    "GetScrollMaxX", "GetScrollMaxY",
    // Drag-drop payload primitives — caller owns memory, payload typing is
    // user-controlled. v2 drag_drop_source/_target containers gate the body;
    // these calls are the payload exchange inside.
    "SetDragDropPayload", "AcceptDragDropPayload", "GetDragDropPayload",
    // Viewport queries.
    "GetMainViewport",
    // Docking internals — DockBuilder* is cherry-picked from imgui_internal.h
    // and used by tests/demos to seed initial layouts. The dockspace/
    // dock_window containers wrap the routine surface; these are the
    // imperative one-shot setup calls.
    "DockBuilderRemoveNode", "DockBuilderAddDockSpaceNode",
    "DockBuilderSetNodeSize", "DockBuilderSetNodePos",
    "DockBuilderSplitNode", "DockBuilderDockWindow", "DockBuilderFinish",
    "DockBuilderGetNode", "DockBuilderCopyNode",
    "DockSpace", "DockSpaceOverViewport"
}

class ImguiLintVisitor : AstVisitor {
    @do_not_delete current_function : Function?

    def override preVisitFunction(var fn : FunctionPtr) : void {
        current_function = fn
    }

    def override visitFunction(var fn : FunctionPtr) : FunctionPtr {
        current_function = null
        return <- fn
    }

    def override preVisitExprCall(var expr : ExprCall?) : void {
        // Combined skip: null guards, macro-generated function bodies, AND
        // macro-synthesized call sites (qmacro emits ExprCalls whose `at`
        // points at the macro template's source file, not the user's file —
        // skip when fileInfo differs from the containing function's).
        if (expr.func == null || expr.func._module == null
                || (current_function != null
                    && (current_function.flags.generated
                        || (current_function.at.fileInfo != null
                            && expr.at.fileInfo != current_function.at.fileInfo)))) return
        let mname = string(expr.func._module.name)
        if (mname == "imgui_boost") {
            let fname = string(expr.func.name)
            compiling_program() |> macro_error(expr.at,
                "IMGUI001: legacy imgui_boost::{fname} is dead — use the v2 wrapper in modules/dasImgui/widgets/")
        } elif (mname == "imgui") {
            let fname = string(expr.func.name)
            if (!key_exists(ALLOWED_IMGUI, fname)) {
                compiling_program() |> macro_error(expr.at,
                    "IMGUI002: raw imgui::{fname} is forbidden under _no_imgui_legacy — add a [widget]/[container]/with_* wrapper in modules/dasImgui/widgets/, or extend ALLOWED_IMGUI in imgui_lint.das if {fname} is genuinely host-agnostic")
            }
        }
    }
}

[lint_macro]
class ImguiLintMacro : AstPassMacro {
    def override apply(prog : ProgramPtr; mod : Module?) : bool {
        let enabled = prog._options |> find_arg("_no_imgui_legacy") ?as tBool ?? false
        if (!enabled) return true
        var v = new ImguiLintVisitor()
        make_visitor(*v) $(adapter) {
            visit_module(prog, adapter, prog.getThisModule)
        }
        unsafe { delete v; }
        return true
    }
}
