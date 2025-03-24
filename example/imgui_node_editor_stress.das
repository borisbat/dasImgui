options gen2
options persistent_heap = true
options gc

require imgui_app
require glfw/glfw_boost
require imgui/imgui_boost
require daslib/static_let
require daslib/safe_addr
require imgui/imgui_node_editor_boost
require opengl/opengl

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
    var io & = unsafe(GetIO())
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
    ImGui_ImplOpenGL3_Shutdown()
    ImGui_ImplGlfw_Shutdown()
    DestroyContext(null)
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


var g_Context : EditorContext?

def EditorDemo() {

    if (g_Context == null) {
        unsafe {
            var config = Config()
            // config.SettingsFile = "Simple.json"
            g_Context = CreateEditor(addr(config))
        }
    }

    // this is how we make sure node editor is full window and resizes
    Begin("Node editor", null, ImGuiWindowFlags.MenuBar | ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove) <| $() {
        var IO & = unsafe(imgui::GetIO())
        SetWindowPos(float2(0., 0.), ImGuiCond.Once)
        SetWindowSize(float2(IO.DisplaySize.x, IO.DisplaySize.y), ImGuiCond.Always)
        // main menu
        MainMenu()
        // editor
        SetCurrentEditor(g_Context)
        Begin("My Editor", float2(0.0, 0.0f)) <| $() {
            static_let <| $() {
                var firstTime = true
            }
            let TOTAL_X = 60
            let TOTAL_Y = 60
            let TOTAL = TOTAL_X * TOTAL_Y
            for (x in range(TOTAL_X)) {
                //BeginChild(uint(100500 + x),float2())
                for (y in range(TOTAL_Y)) {
                    let nodeId = (x + y * TOTAL_X) * 10
                    let inPinId1 = nodeId + 1
                    let inPinId2 = nodeId + 2
                    let outPinId = nodeId + 3
                    if (firstTime) {
                        SetNodePosition(nodeId, float2(x * 250, y * 150))
                    }
                    BeginNode(nodeId) <| $() {
                        Text("Node {x},{y}")
                        ImGuiEx_BeginColumn()
                        BeginPin(inPinId1, PinKind.Input) <| $() {
                            Text("-> In1")
                        }
                        BeginPin(inPinId2, PinKind.Input) <| $() {
                            Text("-> In2")
                        }
                        ImGuiEx_NextColumn()
                        BeginPin(outPinId, PinKind.Output) <| $() {
                            Text("Out ->")
                        }
                        ImGuiEx_EndColumn()
                    }
                }
            }
                //EndChild()
            var ln1 = 13
            var ln2 = 17
            for (x in range(TOTAL_X)) {
                //BeginChild(uint(200500 + x),float2())
                for (y in range(TOTAL_Y)) {
                    let fromNodeId = (x + y * TOTAL_X) * 10 + 3
                    let toNodeId1  = (ln1 % TOTAL) * 10 + 1
                    let toNodeId2  = (ln2 % TOTAL) * 10 + 2
                    let linkId1 = (x + y * TOTAL_X + 1) * 2
                    let linkId2 = linkId1 + 1
                    Link(linkId1, fromNodeId, toNodeId1)
                    Link(linkId2, fromNodeId, toNodeId2)
                    ln1 += 2971
                    ln2 += 3821
                }
            }
                //EndChild()
            firstTime = false
        }
        SetCurrentEditor(null)
    }
}


[export]
def main {
    let t = SaveReasonFlags.None
    imgui_app("Testing IMGUI") <| $() {
        NewFrame()
        EditorDemo()
        Render()
    }
    DestroyEditor(g_Context)
}

