options gen2
options persistent_heap

require math
require rtti
require ast
require daslib/ast_boost
require imgui_app
require glfw/glfw_boost
require imgui/imgui_boost
require daslib/static_let
require imgui/imnodes_boost
require daslib/safe_addr

require opengl/opengl_boost

//////////////////
// basic node view


class NodeView {
    def abstract editNodes(assign_position : bool) : void
    def abstract editLinks : void
}

/////////////////////
// ast implementation

struct AstIdHelper {
    node_id : int = 1
    node2id : table<string; int>
    id2node : table<int; string>
}

def get_id(var helper : AstIdHelper; uid : string) {
    if (helper.node2id |> key_exists(uid)) {
        return helper.node2id.get_value(uid)
    } else {
        var id = helper.node_id ++
        helper.node2id.insert(uid, id)
        helper.id2node.insert(id, uid)
        return id
    }
}

def get_function_id(var helper : AstIdHelper; fun : FunctionPtr) {
    return helper |> get_id("function {get_mangled_name(fun)}")
}

def get_function_argument_id(var helper : AstIdHelper; fun : FunctionPtr; arg : VariablePtr) {
    return helper |> get_id("function {get_mangled_name(fun)} argument {arg.name}")
}


def get_function_result_id(var helper : AstIdHelper; fun : FunctionPtr) {
    return helper |> get_id("function result {get_mangled_name(fun)}")
}

def intptr(expr : ExpressionPtr) {
    var p = intptr(null)
    unsafe {
        return intptr(reinterpret <void?> expr)
    }
}

def get_node_id(var helper : AstIdHelper; expr : ExpressionPtr) {
    return helper |> get_id("{expr.__rtti} {intptr(expr)}")
}

def get_expr_eval_id(var helper : AstIdHelper; expr : ExpressionPtr) {
    return helper |> get_id("{expr.__rtti} eval {intptr(expr)}")
}

def get_expr_var_id(var helper : AstIdHelper; expr : smart_ptr<ExprVar>) {
    return helper |> get_id("{expr.__rtti} variable {intptr(expr)}")
}

def get_expr_field_id(var helper : AstIdHelper; expr : ExpressionPtr; field : string) {
    return helper |> get_id("{expr.__rtti} field {field} {intptr(expr)}")
}

let {
    FUNCTION_VPAD = 20.
    FUNCTION_HPAD = 20.
    BLOCK_VPAD = 20.
    BLOCK_HPAD = 40.
    EXPR_HPAD = 30.
}

struct AstNodeLink {
    lid : int
    from : int
    to : int
}

class AstNodeViewVisitor : AstVisitor {
    helper : AstIdHelper?
    assign_position : bool
    cursor : float2
    hoffset : array<float>
    voffset : array<float>
    vmax : float
    links : array<AstNodeLink>
    def AstNodeViewVisitor(var h : AstIdHelper) {
        assign_position = false
        unsafe {
            helper = addr(h)
        }
    }
    def override preVisitProgram(prog : ProgramPtr) : void {
        links |> clear()
        if (assign_position) {
            cursor = float2(10, 10)
            hoffset |> clear()
            voffset |> clear()
            vmax = 0.
        }
    }
    def override preVisitFunction(fun : FunctionPtr) {
        let id = *helper |> get_function_id(fun)
        BeginNode(id) <| $() {
            BeginNodeTitleBar() <| $() {
                Text("Function {fun.name}")
            }
            for (arg in fun.arguments) {
                let aid = *helper |> get_function_argument_id(fun, arg)
                BeginOutputAttribute(aid) <| $() {
                    Text("{arg.name}")
                }
            }
            if (!fun.result.isVoid) {
                let rid = *helper |> get_function_result_id(fun)
                BeginInputAttribute(rid) <| $() {
                    Text("Result")
                }
            }
        }
        if (assign_position) {
            SetNodeGridSpacePos(id, cursor)
            let dim = GetNodeDimensions(id)
            cursor.y += dim.y + BLOCK_VPAD
            cursor.x += FUNCTION_HPAD
        }
    }
    def override visitFunction(fun : FunctionPtr) {
        if (assign_position) {
            cursor.x -= FUNCTION_HPAD
            cursor.y += FUNCTION_VPAD
        }
        unsafe {
            return fun
        }
    }
    def override preVisitExprBlock(blk : smart_ptr<ExprBlock>) {
        let id = *helper |> get_node_id(blk)
        BeginNode(id) <| $() {
            BeginNodeTitleBar() <| $() {
                Text("ExprBlock")
            }
        }
        if (assign_position) {
            SetNodeGridSpacePos(id, cursor)
            let dim = GetNodeDimensions(id)
            cursor.y += dim.y + BLOCK_VPAD
            hoffset |> push(cursor.x)
            cursor.x += BLOCK_HPAD
        }
    }
    def override preVisitExprBlockExpression(blk : smart_ptr<ExprBlock>; expr : ExpressionPtr) {
        if (assign_position) {
            hoffset |> push(cursor.x)
            voffset |> push(vmax)
            vmax = 0.
        }
    }
    def override visitExprBlockExpression(blk : smart_ptr<ExprBlock>; expr : ExpressionPtr) {
        if (assign_position) {
            cursor.x = hoffset[length(hoffset) - 1]
            hoffset |> pop()
            cursor.y += vmax + BLOCK_VPAD
            vmax = voffset[length(voffset) - 1]
            voffset |> pop()
        }
        unsafe {
            return expr
        }
    }
    def override visitExprBlock(var blk : smart_ptr<ExprBlock>) : ExpressionPtr {
        if (assign_position) {
            cursor.x = hoffset[length(hoffset) - 1]
            hoffset |> pop()
        }
        return <- blk
    }
    def nextExprEval(expr : ExpressionPtr) : void {
        let eid = *helper |> get_expr_eval_id(expr)
        BeginOutputAttribute(eid) <| $() {
            Text("eval")
        }
    }
    def nextExprPos(id : int) : void {
        if (assign_position) {
            SetNodeGridSpacePos(id, cursor)
            let dim = GetNodeDimensions(id)
            cursor.x += dim.x + EXPR_HPAD
            vmax = max(vmax, dim.y)
        }
    }
    def exprFieldEvalPtr(expr : ExpressionPtr; field : string; node : ExpressionPtr) : void {
        let pid = *helper |> get_expr_field_id(expr, field)
        BeginInputAttribute(pid) <| $() {
            Text(field)
        }
        if (node != null) {
            let nid = *helper |> get_expr_eval_id(node)
            let lid = *helper |> get_id("link {expr.__rtti} {intptr(expr)} => {node.__rtti} {intptr(node)}")
            links |> push(AstNodeLink(lid = lid, from = pid, to = nid))
        }
    }
    def override preVisitExprReturn(expr : smart_ptr<ExprReturn>) : void {
        let id = *helper |> get_node_id(expr)
        BeginNode(id) <| $() {
            BeginNodeTitleBar() <| $() {
                Text("ExprReturn")
            }
            self->exprFieldEvalPtr(expr, "subexpr", expr.subexpr)
        }
        self->nextExprPos(id)
    }
    def override preVisitExprVar(expr : smart_ptr<ExprVar>) {
        let id = *helper |> get_node_id(expr)
        BeginNode(id) <| $() {
            BeginNodeTitleBar() <| $() {
                Text("ExprVar")
            }
            let vid = *helper |> get_expr_var_id(expr)
            BeginInputAttribute(vid) <| $() {
                Text("{expr.name}")
            }
            self->nextExprEval(expr)
        }
        self->nextExprPos(id)
    }
    def override preVisitExprOp2(expr : smart_ptr<ExprOp2>) {
        let id = *helper |> get_node_id(expr)
        BeginNode(id) <| $() {
            BeginNodeTitleBar() <| $() {
                Text("ExprOp2 {expr.op}")
            }
            self->exprFieldEvalPtr(expr, "left", expr.left)
            self->exprFieldEvalPtr(expr, "right", expr.right)
            self->nextExprEval(expr)
        }
        self->nextExprPos(id)
    }
}

class AstNodeView : NodeView {
    prog : ProgramPtr
    access : FileAccessPtr
    nvv : AstNodeViewVisitor?
    nvva : smart_ptr<VisitorAdapter>
    @safe_when_uninitialized helper : AstIdHelper
    def AstNodeView(fname : string) {
        helper <- AstIdHelper()
        access := make_file_access("")
        using <| $(var mg : ModuleGroup) {
            using <| $(var cop : CodeOfPolicies) {
                compile_file(fname, access, unsafe(addr(mg)), cop) <| $(ok, program, issues) {
                    if (ok) {
                        prog := program
                    } else {
                        panic("{fname} failed to compile\n{issues}\n")
                    }
                }
            }
        }
        nvv = new AstNodeViewVisitor(helper)
        unsafe {
            nvva <- make_visitor(*nvv)
        }
    }
    def finalize {
        prog := null
        access := null
        nvva := null
        unsafe {
            delete nvv
        }
    }
    def override editNodes(assign_position : bool) : void {
        nvv.assign_position = assign_position
        prog |> visit(nvva)
    }
    def override editLinks : void {
        // print("\n\nlinking\n")
        for (lnk in nvv.links) {
            imnodes::Link(lnk.lid, lnk.from, lnk.to)
        }
    }
}
            // print("{helper.id2node[lnk.lid]}\n")

var g_nodeView : NodeView?

var window : GLFWwindow?

def imgui_app(title : string; blk : block) {
    if (glfwInit() == 0) {
        panic("can't init glfw")
    }
    window = glfwCreateWindow(1920, 1280, title, null, null)
    if (window == null) {
          panic("can't create window")
    }
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)
    CreateContext(null)
    imnodes::CreateContext()
    var io & = imgui::GetIO()
    io.FontGlobalScale = 2.0   // BBATKIN: note - my monitor is HUGE
    StyleColorsDark(null)
    ImGui_ImplGlfw_InitForOpenGL(window, true)
    ImGui_ImplOpenGL3_Init("#version 330")
    var clear_color = float4(0.45f, 0.55f, 0.60f, 1.00f)
    while (glfwWindowShouldClose(window) == 0) {
        glfwPollEvents()
        ImGui_ImplOpenGL3_NewFrame()
        ImGui_ImplGlfw_NewFrame()
        invoke(blk)
        var display_w, display_h : int
        glfwGetFramebufferSize(window, display_w, display_h)
        glViewport(0, 0, display_w, display_h)
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w)
        glClear(GL_COLOR_BUFFER_BIT)
        ImGui_ImplOpenGL3_RenderDrawData(GetDrawData())
        glfwMakeContextCurrent(window)
        glfwSwapBuffers(window)
    }
    imnodes::DestroyContext()
    ImGui_ImplOpenGL3_Shutdown()
    ImGui_ImplGlfw_Shutdown()
    imgui::DestroyContext(null)
    glfwDestroyWindow(window)
    glfwTerminate()
}

def MainMenu() {
    BeginMenuBar <| $() {
        BeginMenu("File") <| $() {
            pass
        }
        BeginMenu("Edit") <| $() {
            MenuItem("Undo", "CTRL+Z") <| $() {
                pass
            }
            MenuItem("Redo", "CTRL+Y", false, false) <| $() {
                pass
            }
            Separator()
            MenuItem("Cut", "CTRL+X") <| $() {
                pass
            }
            MenuItem("Copy", "CTRL+C") <| $() {
                pass
            }
            MenuItem("Paste", "CTRL+V") <| $() {
                pass
            }
        }
    }
}

def EditorDemo() {
    // creating editor context
    static_let <| $() {
        var edc : ImNodesEditorContext?
    }
    if (edc == null) {
        edc = imnodes::EditorContextCreate()
    }
    // this is how we make sure node editor is full window and resizes
    Begin("Node editor", null, ImGuiWindowFlags.MenuBar | ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove) <| $() {
        var IO & = imgui::GetIO()
        SetWindowPos(float2(0., 0.), ImGuiCond.Once)
        SetWindowSize(float2(IO.DisplaySize.x, IO.DisplaySize.y), ImGuiCond.Always)
        // main menu
        MainMenu()
        // editor
        imnodes::EditorContextSet(edc)
        BeginNodeEditor() <| $() {
            // this is how we do context menu for the node editor
            if (BeginPopupContextWindow("Node editor")) {
                Text("Ok")
                if (BeginMenu("Sub-menu")) {
                    MenuItem("Click me")
                    EndMenu()
                }
                EndPopup()
            }
            // nodes
            static_let <| $() {
                var once = true
            }
            g_nodeView->editNodes(once)
            once = false
            g_nodeView->editLinks()
        }
    }
    // link events
    IsLinkCreated <| $(l_from, l_to) {
        print("linked {l_from} {l_to}\n")
    }
    IsLinkDestroyed <| $(l_del) {
        print("unlinked {l_del}\n")
    }
}


[export]
def main {

    g_nodeView = new AstNodeView("example.das")

    var f = 0.0
    imgui_app("Testing IMGUI") <| $() {
        NewFrame()
        EditorDemo()
        Render()
    }
}
