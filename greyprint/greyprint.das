options gen2
// options log_total_compile_time

options multiple_contexts

// OLD das restrictions
options unsafe_table_lookup = false
options strict_smart_pointers = false
options relaxed_pointer_const = true


options persistent_heap = true
options gc

require fio
require imgui_app
require math
require rtti
require debugapi
require stddlg

require glfw/glfw_boost
require imgui/imgui_boost
require daslib/static_let
require daslib/safe_addr
require daslib/defer
require imgui/imgui_node_editor_boost
require daslib/strings_boost
require daslib/lpipe
require opengl/opengl_boost
require opengl/opengl_ttf

require instructions
require instructions_ui
require preview
require guid_2_id
require command_que
require undo_stack

// note - can be different model for every new editor type
require instructions_model
require model_eval
require model
require opengl/opengl_cache

var LEFT_SIDE_PANNEL_WIDTH = 600.
var RIGHT_SIDE_PANNEL_WIDTH = 600.
let CONTEXT_MENU_WIDTH = 600.
let NAVIGATION_TIME = 0.5

// window and app

var window : GLFWwindow?
var g_Context : EditorContext?

def imgui_app(title : string; blk : block) {
    if (glfwInit() == 0) {
        panic("can't init glfw")
    }
    defer <| $() {
        glfwTerminate()
    }
    glfwInitOpenGL(3, 3, false, false)
    var window = glfwCreateWindow(1280, 720, "Greyprint", null, null)
    if (window == null) {
        panic("can't create window")
    }
    defer <| $() {
        glfwDestroyWindow(window)
    }
    glfwMakeContextCurrent(window)

    glfwSwapInterval(1)
    CreateContext(null)
    create_ttf_objects()
    create_preview_objects()
    dlg_init()
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
    imgui::GetStyle() |> ScaleAllSizes(1.5)
    StyleColorsDark(null)
    ImGui_ImplGlfw_InitForOpenGL(window, true)
    ImGui_ImplOpenGL3_Init("#version 330")
    var clear_color = float4(0.05f, 0.05f, 0.15f, 1.00f) // float4(0.45f, 0.55f, 0.60f, 1.00f)
    while (glfwWindowShouldClose(window) == 0) {
        glfwPollEvents()
        ImGui_ImplOpenGL3_NewFrame()
        ImGui_ImplGlfw_NewFrame()
        invoke(blk)
        var display_w, display_h : int
        glfwGetFramebufferSize(window, display_w, display_h)
        bind_ffp()
        glViewport(0, 0, display_w, display_h)
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w)
        glClearDepth(1.0lf)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        draw_preview(display_w, display_h)
        ImGui_ImplOpenGL3_RenderDrawData(GetDrawData())
        glfwMakeContextCurrent(window)
        glfwSwapBuffers(window)

        // now GC
        let total_string_heap = string_heap_bytes_allocated()
        let total_heap = heap_bytes_allocated()
        let t0 = ref_time_ticks()
        unsafe {
            heap_collect(true, true)
        }
        let dt = (get_time_usec(t0) + 500) / 1000
        glfwSetWindowTitle(window, "heap:{int(total_heap)} string:{int(total_string_heap)} collect:{dt}ms")

        var IO & = unsafe(GetIO())
        if (IO.KeyCtrl) {
            if (IsKeyPressed(ImGuiKey.A)) {
                memory_report(false)
            }
        }
    }

    ImGui_ImplOpenGL3_Shutdown()
    ImGui_ImplGlfw_Shutdown()
    DestroyContext(null)
}

// PROJECT

var g_FirstFrame = true
var g_CurrentAction = ""

def save_project(fname : string) {
    let save_text = save_current_project()
    fopen(fname, "wb") <| $(json_file) {
        if (json_file != null) {
            fwrite(json_file, save_text)
        } else {
            get_dlg_ok_from_user("Error", "Can't save {fname}")
        }
    }
}

def export_action(aname, fname : string) {
    let save_text = export_action(g_CurrentProject, aname)
    fopen(fname, "wb") <| $(json_file) {
        if (json_file != null) {
            fwrite(json_file, save_text)
        } else {
            get_dlg_ok_from_user("Error", "Can't save {fname}")
        }
    }
}

def export_project(fname : string) {
    let save_text = produce_project_text()
    fopen(fname, "wb") <| $(das_file) {
        if (das_file != null) {
            fwrite(das_file, save_text)
        } else {
            get_dlg_ok_from_user("Error", "Can't export {fname}")
        }
    }
}

def clear_project_data {
    g_FirstFrame = true
    g_CurrentAction = ""
    SetCurrentEditor(null)
    DestroyEditor(g_Context)
    g_Context = null
    reset_guids()
    (*g_CurrentProject)->clear()
    clear_preview()
    reset_opengl_cache()
}

def check_save_project {
    if (is_undo_dirty()) {
        if (get_dlg_ok_cancel_from_user("Warning.", "You have unsaved changes. Save project?")) {
            let fname = get_dlg_save_file("new_name.greyprint", "", "greyprint")
            if (empty(fname)) {
                return false
            }
            save_project(fname)
        }
    }
    return true
}

def new_project() {
    next_undo_action()
    undo_new_project()
    post_event <| @ {
        clear_project_data()
        update_preview()
        clear_undo_dirty()
    }
}

def load_project(fname : string) {
    var text : string
    fopen(fname, "rb") <| $(json_file) {
        if (json_file != null) {
            fread(json_file) <| $(data) {
                text := data
            }
        } else {
            get_dlg_ok_from_user("Error", "Can't load {fname}")
        }
    }
    if (!empty(text)) {
        post_event <| @ {
            next_undo_action()
            before_project()
            clear_project_data()
            restore_current_project(text)
            undo_load_project()
            update_preview()
            clear_undo_dirty()
        }
    }
}

def import_action(fname : string) {
    var text : string
    fopen(fname, "rb") <| $(json_file) {
        if (json_file != null) {
            fread(json_file) <| $(data) {
                text := data
            }
        } else {
            get_dlg_ok_from_user("Error", "Can't load {fname}")
        }
    }
    if (!empty(text)) {
        post_event <| @ {
            next_undo_action()
            before_project()
            var proj = new Project()
            var action = load_project_from_json(proj, text, true)
            if (!(g_CurrentProject.actions |> key_exists(action.id))) {
                merge_project(g_CurrentProject, proj, float2(0.0), action.id)
                g_CurrentProject.actions[action.id] = action.name
                unsafe {
                    delete proj
                }
                undo_load_project()
                update_preview()
            } else {
                get_dlg_ok_from_user("Error", "Action {action} already exists")
            }
        }
    }
}

var g_ClipboardProject : Project?

def copy {
    var snc = GetSelectedObjectCount()
    if (snc != 0) {
        var sna <- GetSelectedNodes()
        if (length(sna) > 0) {
            var selection : table<string; bool>
            for (ng in sna) {
                let nid = id_2_guid[ng]
                selection[nid] = true
            }
            unsafe {
                delete g_ClipboardProject
            }
            g_ClipboardProject = create_selection_project(g_CurrentProject, selection)
        }
    }
}

def paste {
    if (g_ClipboardProject != null) {
        next_undo_action()
        before_project()
        undo_paste_project(g_ClipboardProject, g_CurrentAction)
        redo_last()
    }
}

// MAIN MENU

def main_menu() {
    BeginMenuBar <| $() {
        BeginMenu("File##Main menu") <| $() {
            if (MenuItem("New##File")) {
                if (check_save_project()) {
                    new_project()
                }
            }
            if (MenuItem("Load##File")) {
                if (check_save_project()) {
                    let fname = get_dlg_open_file("", "greyprint")
                    if (!empty(fname)) {
                        load_project(fname)
                    }
                }
            }
            if (MenuItem("Save##File")) {
                let fname = get_dlg_save_file("new_name.greyprint", "", "greyprint")
                if (!empty(fname)) {
                    save_project(fname)
                    clear_undo_dirty()
                }
            }
            if (MenuItem("Export##File")) {
                let fname = get_dlg_save_file("new_name.das", "", "greyprint")
                if (!empty(fname)) {
                    export_project(fname)
                }
            }
            Separator()
            if (MenuItem("Exit")) {
                if (check_save_project()) {
                    glfwSetWindowShouldClose(window, 1)
                }
            }
        }
        BeginMenu("Edit##Main menu") <| $() {
            if (MenuItem("Undo##Edit", "CTRL+Z")) {
                ClearSelection()
                undo()
            }
            if (MenuItem("Redo##Edit", "CTRL+Y")) {
                ClearSelection()
                redo()
            }
            if (MenuItem("Copy##Edit", "CTRL+C")) {
                copy()
            }
            if (MenuItem("Paste##Edit", "CTRL+V")) {
                ClearSelection()
                paste()
            }
        }
        BeginMenu("Action##Main menu") <| $() {
            if (MenuItem("New##Action")) {
                g_CurrentProject.actions[make_unique_action_name()] = "New action"
            }
            if (MenuItem("New from selection##Action")) {
                g_CurrentProject.actions[make_unique_action_name()] = "New action from selection"
            }
                // TODO: replace selection with action instance
            Separator()
            if (MenuItem("Import##Action")) {
                let fname = get_dlg_open_file("", "action")
                if (!empty(fname)) {
                    import_action(fname)
                }
            }
            if (MenuItem("Export##Action")) {
                if (!empty(g_CurrentAction)) {
                    let fname = get_dlg_save_file("new_name.action", "", "action")
                    if (!empty(fname)) {
                        export_action(g_CurrentAction, fname)
                    }
                }
            }
        }
        BeginMenu("Preview##Main menu") <| $() {
            if (Checkbox("Live preview##Preview_live", safe_addr(g_LivePreview))) {
                update_preview()
            }
            Checkbox("Preview labels##Preview_labels", safe_addr(g_PreviewLabels))
            Checkbox("Always lit##Preview_always_lit", safe_addr(g_AlwaysLitPreview))
            Separator()
            ListBox("Preview mode##box_or_sphere", g_PreviewMode)
            Separator()
            if (MenuItem("View generated code##Preview")) {
                g_ProjectSource = produce_project_text()
                post_event <| @ {
                    OpenPopup("PREVIEW SOURCE")
                }
            }
        }
    }

    var IO & = unsafe(GetIO())
    if (IO.KeyCtrl) {
        if (IsKeyPressed(ImGuiKey.Z)) {
            ClearSelection()
            undo()
        }
        if (IsKeyPressed(ImGuiKey.Y)) {
            ClearSelection()
            redo()
        }
        if (IsKeyPressed(ImGuiKey.C)) {
            copy()
        }
        if (IsKeyPressed(ImGuiKey.V)) {
            ClearSelection()
            paste()
        }
    }
}

// NODE EDITOR WINDOW

def in_pin(id : int; blk : block<() : void>) {
    // imgui_node_editor::PushStyleVar(StyleVar StyleVar_PinArrowSize, 10f)
    // imgui_node_editor::PushStyleVar(StyleVar StyleVar_PinArrowWidth, 10f)
    // imgui_node_editor::PushStyleColor(StyleColor StyleColor_PinRect, float4(1f, 0f, 0f, 1f))
    // imgui_node_editor::PushStyleVar(StyleVar StyleVar_PinCorners, 3f)
    BeginPin(id, PinKind.Input) <| $() {
        var IO & = unsafe(GetIO())
        Dummy(float2(10. * IO.FontGlobalScale))
        let offset = float2(3, 3)
        let min = GetItemRectMin() - float2(8, 0)
        let max = GetItemRectMax() - float2(8, 0)
        var drawList = GetWindowDrawList()
        // *drawList |> AddRectFilled(min, max, 0xFFFFFFFF)
        *drawList |> AddTriangleFilled(min, float2(max.x, (min.y + max.y) * 0.5), float2(min.x, max.y), 0xFFFFFFFF)
        // *drawList |> AddCircleFilled((min + max) * 0.5, 5f, 0xFFFFFFFF)// 0xFFFFb032)
        PinRect(min - offset, max + offset)
        let pin = float2(min.x, (min.y + max.y) * 0.5) + float2(1, 0)
        PinPivotRect(pin, pin)
        blk |> invoke()
    }
}
    // imgui_node_editor::PopStyleVar(2)
    // imgui_node_editor::PopStyleColor(1)

def out_pin(id : int; text : string implicit; blk : block<() : void>) {
    out_pin(id, text, DEFAULT_NODE_WIDTH - CalcTextSize(text).x, blk)
}

def out_pin(id : int; text : string implicit; indent : float; blk : block<() : void>) {
    ImGuiEx_BeginColumn()
    if (indent > 0f) {
        imgui::Indent(indent)
    }
    imgui::TextUnformatted(text)
    blk |> invoke()
    ImGuiEx_NextColumn()
    // imgui_node_editor::PushStyleVar(StyleVar StyleVar_PinArrowSize, 10f)
    // imgui_node_editor::PushStyleVar(StyleVar StyleVar_PinArrowWidth, 10f)
    // imgui_node_editor::PushStyleVar(StyleVar StyleVar_PinCorners, 3f)
    // let size = GetNodeSize()
    // SetNextItemWidth(-FLT_MIN)
    BeginPin(id, PinKind.Output) <| $() {
        var IO & = unsafe(GetIO())
        Dummy(float2(10. * IO.FontGlobalScale))
        let offset = float2(3, 3)
        let min = GetItemRectMin() + float2(8, 3)
        let max = GetItemRectMax() + float2(8, 3)
        var drawList = GetWindowDrawList()
        // *drawList |> AddRectFilled(min, max, 0xFFFFFFFF)
        // *drawList |> AddCircleFilled((min + max) * 0.5, 5f, 0xFFFFFFFF)
        *drawList |> AddTriangleFilled(min, float2(max.x, (min.y + max.y) * 0.5), float2(min.x, max.y), 0xFFFFFFFF)
        PinRect(min - offset, max + offset)
        let pin = float2(min.x, (min.y + max.y) * 0.5) + float2(9, 0)
        PinPivotRect(pin, pin)
    }
    //blk |> invoke()
    // imgui_node_editor::PopStyleVar(2)
    ImGuiEx_EndColumn()
}

def editor_hint(desc : string) {
    Suspend()
    BeginTooltip()
    PushTextWrapPos(GetFontSize() * 35.0f)
    TextUnformatted(desc)
    PopTextWrapPos()
    EndTooltip()
    Resume()
}

def editor_child_window() {
    var style & = unsafe(imgui_node_editor::GetStyle())
    style.NodeRounding = 0f
    style.GroupRounding = 0f
    style.PinRounding = 0f
    style.NodePadding = float4(4)
    style.Colors[int(StyleColor.Bg)].w = 0.
    style.Colors[int(StyleColor.Grid)].w = 0.
    static_let <| $() {
        var largePreviewTex = null
    }
    var openPreview = false
    Begin("My Editor", float2(0.0, 0.0f)) <| $() {
        for (inst in g_CurrentProject.instructions) {
            if (inst.action != g_CurrentAction) {
                continue
            }
            let id = get_unique_id(inst.id)
            if (!inst.flags.Comment) {
                // REGULAR NODE
                BeginNode(id) <| $() {
                    Dummy(float2(DEFAULT_NODE_WIDTH, 0.))
                    ImGuiEx_BeginColumn()
                    Text(inst.name)
                    let sz = ImGuiEx_NextColumn()
                    Dummy(float2(DEFAULT_NODE_WIDTH - sz.x, 0.))
                    SameLine()
                    if (Button("[X]##{inst.id}_E")) {
                        next_undo_action()
                        DeleteNode(id)
                    }
                    ImGuiEx_EndColumn()
                    if (inst.tex != null) {
                        Image(inst.tex, float2(128, 128), float2(0., 0.), float2(1., 1.), float4(1), float4(1))
                    }
                    ImGuiEx_BeginColumn()
                    for (inp in inst.pins.inputs) {
                        let inp_id = get_input_unique_id(inst, inp.name)
                        in_pin(inp_id) <| $() {
                            SameLine()
                            Text("{get_display_name(inp)}:{inp._type}")
                            SameLine()
                            if (inp.src != null) {
                                SameLine()
                                if (Button("[G]##goto_{inp.src.id}_from_{inst.id}")) {
                                    SelectNode(id, false)
                                    NavigateToSelection(false, NAVIGATION_TIME)
                                    ClearSelection()
                                }
                                SameLine()
                                if (Button("[X]##goto_{inp.src.id}_from_{inst.id}")) {
                                    next_undo_action()
                                    DeleteLink(inp_id)
                                }
                            }
                        }
                    }
                    let lw = ImGuiEx_NextColumn()
                    for (outp in inst.pins.outputs) {
                        let outp_id = get_output_unique_id(inst, outp.name)
                        let text = "{get_display_name(outp)}:{outp._type}"
                        out_pin(outp_id, text, DEFAULT_NODE_WIDTH - CalcTextSize(text).x - lw.x) <| $() {
                            SameLine()
                            unsafe {
                                if (Checkbox("##prewview_{inst.id}_{outp.name}_E", addr(outp.preview))) {
                                    update_preview()
                                }
                            }
                            if (outp.tex != null) {
                                Image(outp.tex, float2(128, 128), float2(0., 0.), float2(1., 1.), float4(1), float4(1))
                                if (IsItemClicked()) {
                                    largePreviewTex = outp.tex
                                    openPreview = true
                                }
                            }
                        }
                    }
                    ImGuiEx_EndColumn()
                }
            } else {
                var comment : string
                unsafe {
                    let cinst = upcast<Instruction_Comment?> inst
                    comment = cinst.comment
                }
                let commentAlpha = 0.75f
                PushStyleVar(ImGuiStyleVar.Alpha, commentAlpha)
                imgui_node_editor::BeginNode(id)
                Text(comment)
                Group(inst.extents)
                EndNode()
                imgui::PopStyleVar(1)
                inst.extents = GetNodeSize(id)
                if (BeginGroupHint(id)) {
                    let bgAlpha = int(imgui::GetStyle().Alpha * 255.)
                    imgui::PushStyleVar(ImGuiStyleVar.Alpha, commentAlpha * imgui::GetStyle().Alpha)
                    let minR = GetGroupMin()
                    SetCursorScreenPos(minR - float2(-8., GetTextLineHeightWithSpacing() + 4.))
                    BeginGroup()
                    TextUnformatted(inst.name)
                    EndGroup()
                    var drawList = GetHintBackgroundDrawList()
                    var hintBounds      = ImGui_GetItemRect()
                    var hintFrameBounds = ImRect_Expanded(hintBounds, 8., 4.)
                    (*drawList) |> AddRectFilled(
                        hintFrameBounds |> GetTL(),
                        hintFrameBounds |> GetBR(),
                        IM_COL32(255, 255, 255, 64 * bgAlpha / 255), 4.0f)
                    (*drawList) |> AddRect(
                        hintFrameBounds |> GetTL(),
                        hintFrameBounds |> GetBR(),
                        IM_COL32(255, 255, 255, 128 * bgAlpha / 255), 4.0f)
                    imgui::PopStyleVar()
                }
                EndGroupHint()
            }
        }
        var moves : array<tuple<string; float2; float2>>
        var nav = false
        for (inst in g_CurrentProject.instructions) {
            if (inst.action != g_CurrentAction) {
                continue
            }
            let id = get_unique_id(inst.id)
            if (inst.firstFrame) {
                if (!inst.hasPosition) {
                    CenterNodeOnScreen(id)
                } else {
                    SetNodePosition(id, inst.at)    // note: what we set and what gets returned differs (via m_Bounds.floor())
                }
                inst.at = GetNodePosition(id)
                inst.firstFrame = false
            } else {
                let newAt = GetNodePosition(id)
                if (inst.at != newAt) {
                    moves |> push((inst.id, inst.at, newAt))
                    inst.at = newAt
                }
            }
            if (inst.select) {
                SelectNode(id, true)
                nav ||= inst.navigate
                inst.select = false
            }
        }
        if (length(moves) != 0) {
            next_undo_action()
            undo_move_instructions(moves)
            delete moves
        }
        if (nav) {
            NavigateToSelection(false, NAVIGATION_TIME)
        }

        for (inst in g_CurrentProject.instructions) {
            if (inst.action != g_CurrentAction) {
                continue
            }
            for (inp in inst.pins.inputs) {
                if (inp.src != null) {
                    let inp_id = get_input_unique_id(inst, inp.name)
                    let outp_id = get_output_unique_id(inp.src, inp.output)
                    Link(inp_id, inp_id, outp_id)
                }
            }
        }


        /*
        if (ed::ShowNodeContextMenu(&contextNodeId))
            ImGui::OpenPopup("Node Context Menu")
        else if (ed::ShowPinContextMenu(&contextPinId))
            ImGui::OpenPopup("Pin Context Menu")
        else if (ed::ShowLinkContextMenu(&contextLinkId))
            ImGui::OpenPopup("Link Context Menu")
        else if (ed::ShowBackgroundContextMenu())
        {
            ImGui::OpenPopup("Create New Node")
            newNodeLinkPin = nullptr
        }
        */

        BeginCreate(float4(1), 1.0f) <| $() {
            var inputPinId, outputPinId : PinId
            if (QueryNewLink(safe_addr(inputPinId), safe_addr(outputPinId))) {
                if (inputPinId != 0 && outputPinId != 0) {// both are valid, let's accept link
                    if (inputPinId == outputPinId) {
                        RejectNewItem()
                    } else {
                        if (id_2_guid[inputPinId] |> starts_with("OUTPUT")) {
                            swap(inputPinId, outputPinId)
                        }
                        if (!(id_2_guid[inputPinId] |> starts_with("INPUT")) || !(id_2_guid[outputPinId] |> starts_with("OUTPUT"))) {
                            RejectNewItem()
                        } else {
                            var inL = translate_input_output_id(inputPinId, "INPUT")
                            var outL = translate_input_output_id(outputPinId, "OUTPUT")
                            let inI = inL.inst->input_index(inL.pin)
                            assert(inI != -1)
                            let outI = outL.inst->output_index(outL.pin)
                            assert(outI != -1)
                            if (inL.inst == outL.inst) {// linking to itself
                                editor_hint("Error: can't link to itself")
                                RejectNewItem(float4(1, 0, 0, 1), 3.)
                            } elif (inL.inst.pins.inputs[inI]._type != outL.inst.pins.outputs[outI]._type) {// type mismatch
                                editor_hint("Error: can't link {inL.inst.pins.inputs[inI]._type} to {outL.inst.pins.outputs[outI]._type}")
                                RejectNewItem(float4(1, 0, 0, 1), 3.)
                            } else {
                                before_link(inL.inst.id, inL.pin)
                                var old_input = inL.inst.pins.inputs[inI]
                                inL.inst.pins.inputs[inI] |> connect(outL.inst, outL.pin)
                                if (g_CurrentProject |> find_loop()) {
                                    inL.inst.pins.inputs[inI] = old_input
                                    editor_hint("Error: link creates loop")
                                    RejectNewItem(float4(1, 0, 0, 1), 3.)
                                } else {
                                    AcceptNewItem()
                                    next_undo_action()
                                    undo_create_connection(inL.inst.id, inL.pin)
                                    update_preview()
                                }
                            }
                        }
                    }
                }
            }
        }

        BeginDelete() <| $() {
            var deletedLinkId : LinkId
            while (QueryDeletedLink(safe_addr(deletedLinkId), null, null)) {
                if (AcceptDeletedItem()) {
                    post_event <| @ {
                        delete_connection(deletedLinkId)
                    }
                }
            }
            var deletedNodeId : NodeId
            while (QueryDeletedNode(safe_addr(deletedNodeId))) {
                if (AcceptDeletedItem()) {
                    post_event <| @ {
                        let inst_id = id_2_guid[deletedNodeId]
                        var inst = (*g_CurrentProject)->find_instruction(inst_id)
                        assert(inst != null)
                        delete_instruction(inst)
                    }
                }
            }
        }

        instruction_context_menu()
    }

    if (openPreview) {
        openPreview = false
        OpenPopup("LARGE PREVIEW")
    }
    if (IsPopupOpen("LARGE PREVIEW")) {
        var tsize : int2
        unsafe {
            tsize = getTexture2DSize(reinterpret<uint> largePreviewTex)
        }
        SetNextWindowSize(float2(tsize.x + 40, tsize.y + 40))
        if (BeginPopup("LARGE PREVIEW")) {
            Image(largePreviewTex, float2(tsize.x, tsize.y), float2(0., 0.), float2(1., 1.), float4(1), float4(1))
            EndPopup()
        }
    }
    if (g_FirstFrame) {
        NavigateToContent(NAVIGATION_TIME)
    }
    g_FirstFrame = false
}

// SIDE WINDOW

def delete_instruction(var inst : Instruction?) {
    before_instruction(inst)
    undo_delete_instruction(inst)
    redo_last()
    update_preview()
}

def delete_connection(id : LinkId) {
    var inL = translate_input_output_id(id, "INPUT")
    undo_delete_connection(inL.inst.id, inL.pin)
    redo_last()
    update_preview()
}

def side_edit_instance(var inst : Instruction?; flags : ImGuiTreeNodeFlags = ImGuiTreeNodeFlags.None) {
    if (TreeNodeEx("side_{inst.id}{flags}", flags, "{inst.name}")) {
        if (Button("[G]##goto_{inst.id}")) {
            SelectNode(get_unique_id(inst.id), false)
            NavigateToSelection(false, NAVIGATION_TIME)
            ClearSelection()
        }
        HelpMarker("Navigate to node")
        SameLine()
        if (Button("<C>##{inst.id}_S")) {
            CenterNodeOnScreen(get_unique_id(inst.id))
        }
        HelpMarker("Center")
        SameLine()
        if (Button("[X]##{inst.id}_S")) {
            next_undo_action()
            DeleteNode(get_unique_id(inst.id))
        }
        HelpMarker("Delete")
        Text("id: `{inst.id}`")
        Text("at: {inst.at}")
        before_instruction(inst)
        var buf = get_next_text_buffer(inst.name)
        if (InputText("name##{inst.id}_EDIT", *buf)) {
            inst.name = to_string(*buf)
            undo_edit_instruction(inst.id, "name")
            update_preview()
        }
        for (outp in inst.pins.outputs) {
            unsafe {
                if (Checkbox("##preview_{inst.id}_{outp.name}_S", addr(outp.preview))) {
                    update_preview()
                }
            }
            SameLine()
            Text("-> {get_display_name(outp)}:{outp._type}")
        }
        if (inst.flags.HasEdit) {
            inst->edit(EditMode.Sidebar)
        }
        TreePop()
    }
}

// context menu

def instruction_context_menu {
    let icm = "Create New Instruction"
    static_let <| $() {
        var link_inst : Instruction?
        var link_pin : string
        var node_pos : float2
    }
    Suspend()
    if (ShowBackgroundContextMenu()) {
        OpenPopup(icm)  // contextless node
        link_inst = null
        node_pos = ScreenToCanvas(GetMousePos())
    }
    var context_link_id = 0
    if (ShowLinkContextMenu(safe_addr(context_link_id))) {
        OpenPopup(icm)  // link node
        var inL = translate_input_output_id(context_link_id, "INPUT")
        link_inst = inL.inst
        link_pin = inL.pin
    }
    if (!IsPopupOpen("", ImGuiPopupFlags.AnyPopupId)) {
        if (IsKeyPressed(ImGuiKey.Tab) || IsKeyPressed(ImGuiKey.Space)) {
            var snc = GetSelectedObjectCount()
            if (snc == 1) {
                var sna <- GetSelectedNodes()
                var snl <- GetSelectedLinks()
                if (length(sna) == 1) {
                    let nid = id_2_guid[sna[0]]
                    var outL = (*g_CurrentProject)->find_instruction(nid)
                    assert(outL != null)
                    if (length(outL.pins.outputs) >= 1) {
                        OpenPopup(icm)  // tab node
                        link_inst = outL
                        link_pin = ""
                    }
                } elif (length(snl) == 1) {
                    OpenPopup(icm)  // link node
                    context_link_id = snl[0]
                    var inL = translate_input_output_id(context_link_id, "INPUT")
                    link_inst = inL.inst
                    link_pin = inL.pin
                }
                delete sna
                delete snl
            } elif (snc == 0) {
                OpenPopup(icm)  // contextless node
                link_inst = null
                node_pos = float2(-FLT_MAX)
            }
        }
    }
    if (BeginPopup(icm)) {
        if (link_inst == null) {
            create_instruction_contextless(node_pos)
        } elif (!empty(link_pin)) {
            edit_link_instructions(link_inst, link_pin)
        } else {
            edit_tab_instructions(link_inst, link_inst.pins.outputs[0].name)
        }
        EndPopup()
    }
    Resume()
}

bitfield EditInstructionsFlags {
    FromContextMenu
    DisplayCategories
}

def create_instruction_ex(flags : EditInstructionsFlags; evt : block<(ai : InstructionCategory?#; action : string) : void>; skip : block<(ai : InstructionCategory?#) : bool>) {
    if (flags.FromContextMenu) {
        Text("Create new instruction")
    }
    static_let <| $() {
        var filter = new ImGuiTextFilter
    }
    *filter |> Draw("##edit_instruction", (flags.FromContextMenu ? CONTEXT_MENU_WIDTH : LEFT_SIDE_PANNEL_WIDTH) - 10.)
    if (flags.FromContextMenu) {
        if (IsWindowAppearing()) {
            SetKeyboardFocusHere()
        }
        if (IsKeyPressed(ImGuiKey.Escape)) {
            CloseCurrentPopup()
        }
    }
    var make_first = false
    if (flags.FromContextMenu && IsKeyPressed(ImGuiKey.Enter)) {
        make_first = true
    }
    var prevCategory = ""
    var collapsed = true
    var stx = 0.
    if (length(g_CurrentProject.actions) > 0) {
        if (flags.DisplayCategories) {
            prevCategory = "Custom actions"
            collapsed = !TreeNodeEx(prevCategory, ImGuiTreeNodeFlags.DefaultOpen)
            stx = 0.
        }
        if (!collapsed || !flags.DisplayCategories) {
            for (actid, actname in keys(g_CurrentProject.actions), values(g_CurrentProject.actions)) {
                if (!((*filter) |> PassFilter(actname))) {
                    continue
                }
                if (stx != 0. && stx < CONTEXT_MENU_WIDTH) {
                    SameLine()
                } else {
                    stx = 0.
                }
                if (Button("{actname}##action_S") || make_first) {
                    make_first = false
                    if (flags.FromContextMenu) {
                        CloseCurrentPopup()
                    }
                    var idx = g_instructionsByCategory |> find_index_if <| $(val) {
                        return val.name == "Call action"
                    }
                    assert(idx != -1, "Call action not found")
                    var ai & = unsafe(g_instructionsByCategory[idx])
                    invoke(evt, safe_addr(ai), actid)
                }
                stx += GetItemRectSize().x
            }
        }
    }
    for (ai in g_instructionsByCategory) {
        if (prevCategory != ai.category) {
            prevCategory = ai.category
            if (flags.DisplayCategories) {
                if (!collapsed) {
                    TreePop()
                }
                collapsed = !TreeNodeEx(ai.category, ImGuiTreeNodeFlags.DefaultOpen)
                stx = 0.
            }
        }
        if (!collapsed || !flags.DisplayCategories) {
            if (ai.name == "Call action") {
                continue
            }
            if (!((*filter) |> PassFilter(ai.name))) {
                continue
            }
            if (skip |> invoke(safe_addr(ai))) {
                continue
            }
            if (stx != 0. && stx < CONTEXT_MENU_WIDTH) {
                SameLine()
            } else {
                stx = 0.
            }
            if (Button("{ai.name}##make_S") || make_first) {
                make_first = false
                if (flags.FromContextMenu) {
                    CloseCurrentPopup()
                }
                invoke(evt, safe_addr(ai), "")
            }
            stx += GetItemRectSize().x
        }
    }
    if (flags.DisplayCategories) {
        if (!collapsed) {
            TreePop()
        }
    }
}

def make_instruction_ex(type_name, aname : string) {
    var res = make_instruction(type_name)
    if (!empty(aname)) {
        assert(type_name == "Instruction_CallAction")
        unsafe {
            var pact = upcast<Instruction_CallAction?> res
            pact.fn = aname
        }
    }
    return res
}

def create_instruction_contextless(pos : float2) {
    create_instruction_ex(EditInstructionsFlags.DisplayCategories | EditInstructionsFlags.FromContextMenu) <| $(ai, aname) {
        let type_name : string := ai.tname
        post_event() <| @ {// context free instruction at mouse position
            next_undo_action()
            var inst = make_instruction_ex(type_name, aname)
            inst.action = g_CurrentAction
            (*g_CurrentProject)->add_new_insturction(inst)
            (*inst)->pre_sync()
            ClearSelection()
            inst.select = true
            inst.at = pos
            inst.hasPosition = pos != float2(-FLT_MAX)
            undo_create_instruction(inst)
            update_preview()
        }
    }
    lpipe <| $(ai) {
        return false
    }
}

def edit_link_instructions(var inst : Instruction?; pin : string) {
    let pid = inst->input_index(pin)
    assert(pid != -1)
    let iotype = inst.pins.inputs[pid]._type
    create_instruction_ex(EditInstructionsFlags.FromContextMenu) <| $(ai, aname) {
        let type_name : string := ai.tname
        post_event() <| @ {// link between input and output
            next_undo_action()
            var link_inst = make_instruction_ex(type_name, aname)
            link_inst.action = g_CurrentAction
            (*g_CurrentProject)->add_new_insturction(link_inst)
            (*link_inst)->pre_sync()
            ClearSelection()
            link_inst.select = true
            let p0 = GetNodePosition(guid_2_id[inst.id])
            let p1 = GetNodePosition(guid_2_id[inst.pins.inputs[pid].src.id])
            link_inst.at = (p0 + p1) * 0.5
            link_inst.hasPosition = true
            before_link(link_inst.id, link_inst.pins.inputs[0].name)
            link_inst.pins.inputs[0].src = inst.pins.inputs[pid].src
            link_inst.pins.inputs[0].output = inst.pins.inputs[pid].output
            undo_create_instruction(link_inst)
            undo_create_connection(link_inst.id, link_inst.pins.inputs[0].name)
            before_link(inst.id, pin)
            inst.pins.inputs[pid].src = link_inst
            inst.pins.inputs[pid].output = link_inst.pins.outputs[0].name
            undo_create_connection(inst.id, pin)
            update_preview()
        } finally {
            inst = null
        }
    }
    lpipe <| $(ai) {
        return ai.main_in != iotype || ai.main_out != iotype
    }
}

def edit_tab_instructions(var inst : Instruction?; pin : string) {
    let pid = inst->output_index(pin)
    assert(pid != -1)
    let iotype = inst.pins.outputs[pid]._type
    create_instruction_ex(EditInstructionsFlags.FromContextMenu) <| $(ai, aname) {
        let type_name : string := ai.tname
        post_event() <| @ {// link to main output
            next_undo_action()
            var out_inst = make_instruction_ex(type_name, aname)
            out_inst.action = g_CurrentAction
            (*g_CurrentProject)->add_new_insturction(out_inst)
            (*out_inst)->pre_sync()
            ClearSelection()
            out_inst.select = true
            out_inst.navigate = true
            out_inst.at = inst.at + float2(DEFAULT_NODE_WIDTH + 200.0, 0.)
            out_inst.hasPosition = true
            let srcpin = out_inst.pins.inputs[0].name
            before_link(out_inst.id, srcpin)
            out_inst.pins.inputs[0].src = inst
            out_inst.pins.inputs[0].output = pin
            undo_create_instruction(out_inst)
            undo_create_connection(out_inst.id, srcpin)
            update_preview()
        } finally {
            inst = null
        }
    }
    lpipe <| $(ai) {
        return ai.main_in != iotype
    }
}

var g_ProjectSource = ""
var g_ProjectErrors = ""
var g_ProjectErrorsMessage = ""

def eval_project() {
    var failed = false
    g_ProjectSource = produce_project_text()
    g_ProjectErrors = ""
    g_ProjectErrorsMessage = ""
    var t0 = ref_time_ticks()
    compile("project", g_ProjectSource, CodeOfPolicies(), false) <| $(ok; prog; errors) {
        let compile_sec = double(get_time_usec(t0)) / 1000000.0lf
        if (ok) {
            var t1 = ref_time_ticks()
            simulate(prog) <| $(sok; context; serrors) {// no aot for now
                let simulate_sec = double(get_time_usec(t1)) / 1000000.0lf
                if (sok) {
                    unsafe {
                        var t2 = ref_time_ticks()
                        try {
                            invoke_in_context(context, "main")
                        } recover {
                            let ctx = reinterpret<Context?> context
                            g_ProjectErrorsMessage = "generated project failed to simulate"
                            g_ProjectErrors = "{ctx.exception}, at {ctx.exceptionAt}"
                            failed = true
                        }
                        let run_sec = double(get_time_usec(t2)) / 1000000.0lf
                        // print("compile={compile_sec} simulate={simulate_sec}, run={run_sec}\n{errors}\n")
                        if (!failed) {
                            var pout = get_context_global_variable(context, "G_OUTPUT")
                            if (pout != null) {
                                var OUTPUT  & = *(reinterpret<array<Material#>?> pout)
                                clear_preview()
                                for (inst in g_CurrentProject.instructions) {
                                    inst.tex = null
                                    for (outp in inst.pins.outputs) {
                                        outp.tex = null
                                    }
                                }
                                for (outprev in OUTPUT) {
                                    var tex = outprev.surf.tex
                                    g_PreviewTexture |> push_clone(outprev)
                                    var pinst = (*g_CurrentProject)->find_instruction(outprev.id)
                                    assert(pinst != null)
                                    if (!empty(outprev.outp)) {
                                        pinst |> find_output(outprev.outp) <| $(outp) {
                                            if (outp != null) {
                                                outp.tex = reinterpret<void?> tex
                                            }
                                        }
                                    } else {
                                        pinst.tex = reinterpret<void?> tex
                                    }
                                }
                            }
                        }
                    }
                } else {
                    g_ProjectErrorsMessage = "generated code failed to simulate"
                    g_ProjectErrors = "{serrors}"
                    failed = true
                }
            }
        } else {
            g_ProjectErrorsMessage = "generated code failed to compile"
            g_ProjectErrors = "{errors}"
            failed = true
        }
    }
}

var g_RenameAction = ""
var g_RenameActionId = ""

def rename_action_dialog() {
    if (BeginPopup("RENAME ACTION")) {
        Text("Rename action")
        var buf = get_next_text_buffer(g_RenameAction, 128)
        SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH)
        if (InputText("##action_name", *buf)) {
            g_RenameAction = to_string(*buf)
        }
        if (Button("OK##action_name")) {
            next_undo_action()
            undo_rename_action(g_RenameActionId, g_CurrentProject.actions[g_RenameActionId], g_RenameAction)
            redo_last()
            CloseCurrentPopup()
        }
        SameLine()
        if (Button("CANCEL##action_name")) {
            CloseCurrentPopup()
        }
        EndPopup()
    }
}

def project_window() {
    var style & = unsafe(imgui::GetStyle())
    PushStyleColor(ImGuiCol.ChildBg, style.Colors[int(ImGuiCol.WindowBg)])
    BeginGroup()
    BeginChild("Project", float2(LEFT_SIDE_PANNEL_WIDTH, -FLT_MIN), ImGuiChildFlags.Border)
    if (!empty(g_CurrentAction)) {
        Text(g_CurrentAction)
        if (Button("Rename##rename_action")) {
            g_RenameAction = g_CurrentProject.actions[g_CurrentAction]
            g_RenameActionId = g_CurrentAction
            OpenPopup("RENAME ACTION")
        }
        SameLine()
        Text(g_CurrentProject.actions[g_CurrentAction])
    }
    rename_action_dialog()
    if (Button("[*]##navigate_to_content")) {
        NavigateToContent(NAVIGATION_TIME)
    }
    HelpMarker("Navigate to content")
    SameLine()
    static_let <| $() {
        var project_filter = new ImGuiTextFilter
    }
    *project_filter |> Draw("", LEFT_SIDE_PANNEL_WIDTH - 10.)
    let tact = length(g_CurrentProject.actions)
    if (tact > 0) {
        for (actid, actname in keys(g_CurrentProject.actions), values(g_CurrentProject.actions)) {
            if (TreeNodeEx("action_{actid}", ImGuiTreeNodeFlags.DefaultOpen, actname)) {
                for (inst in g_CurrentProject.instructions) {
                    if (inst.action != actid) {
                        continue
                    }
                    if (*project_filter |> PassFilter(inst.name) || *project_filter |> PassFilter(inst.id)) {
                        side_edit_instance(inst)
                    }
                }
                TreePop()
            }
        }
        if (TreeNodeEx("project_", ImGuiTreeNodeFlags.DefaultOpen, "Project")) {
            for (inst in g_CurrentProject.instructions) {
                if (inst.action != "") {
                    continue
                }
                if (*project_filter |> PassFilter(inst.name) || *project_filter |> PassFilter(inst.id)) {
                    side_edit_instance(inst)
                }
            }
            TreePop()
        }
    } else {
        for (inst in g_CurrentProject.instructions) {
            if (*project_filter |> PassFilter(inst.name) || *project_filter |> PassFilter(inst.id)) {
                side_edit_instance(inst)
            }
        }
    }
    EndChild()
    EndGroup()
    imgui::PopStyleColor()
}

def properties_window() {
    var style & = unsafe(imgui::GetStyle())
    PushStyleColor(ImGuiCol.ChildBg, style.Colors[int(ImGuiCol.WindowBg)])
    BeginGroup()
    var snc = GetSelectedObjectCount()
    if (snc != 0) {
        var sna <- GetSelectedNodes()
        BeginChild("Selection", float2(RIGHT_SIDE_PANNEL_WIDTH, -FLT_MIN), ImGuiChildFlags.Border)
        if (Button("[X]##delete selection")) {
            next_undo_action()
            for (ng in sna) {
                DeleteNode(ng)
            }
        }
        HelpMarker("Delete selection")
        SameLine()
        if (Button("[*]##navigate to selection")) {
            NavigateToSelection(true, 0.5)
        }
        HelpMarker("Navigate to selection")
        for (ng in sna) {
            let nid = id_2_guid[ng]
            var inst = (*g_CurrentProject)->find_instruction(nid)
            side_edit_instance(inst, ImGuiTreeNodeFlags.DefaultOpen)
        }
        EndChild()
    }
    EndGroup()
    imgui::PopStyleColor()
}

// error preview

def preview_errors {
    if (!empty(g_ProjectErrors)) {
        if (Button("[!]##PROJECT ERRORS")) {
            OpenPopup("EVAL")
        }
        SameLine()
        TextColored(float4(1., 0.5, 0., 1.), g_ProjectErrorsMessage)
    }
    if (IsPopupOpen("EVAL")) {
        SetNextWindowSize(float2(1280., 800.0))
        if (BeginPopup("EVAL", ImGuiWindowFlags.HorizontalScrollbar)) {
            BeginGroup()
            TextUnformatted(g_ProjectSource)
            TextUnformatted("")
            TextColored(float4(1., 0.5, 0., 1.0), g_ProjectErrorsMessage)
            TextUnformatted("")
            TextUnformatted(g_ProjectErrors)
            EndGroup()
            EndPopup()
        }
    }
    if (IsPopupOpen("PREVIEW SOURCE")) {
        SetNextWindowSize(float2(1280., 800.0))
        if (BeginPopup("PREVIEW SOURCE", ImGuiWindowFlags.HorizontalScrollbar)) {
            BeginGroup()
            TextUnformatted(g_ProjectSource)
            EndGroup()
            EndPopup()
        }
    }
}

// MAIN WINDOW

def main_editor_screen() {
    if (g_Context == null) {
        unsafe {
            var config = Config()
            // config.SettingsFile = ""
            g_Context = CreateEditor(safe_addr(config))
        }
        SetCurrentEditor(g_Context)
    }
        /*
        SetCurrentEditor(g_Context)
        EnableShortcuts(true)
        SetCurrentEditor(null)
        */
    PushStyleVar(ImGuiStyleVar.WindowPadding, float2())
    Begin("Surface project editor", null, ImGuiWindowFlags.MenuBar | ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoBackground) <| $() {
        imgui::PopStyleVar(1)
        var IO & = unsafe(imgui::GetIO())
        SetWindowPos(float2(0., 0.), ImGuiCond.Once)
        SetWindowSize(float2(IO.DisplaySize.x, IO.DisplaySize.y), ImGuiCond.Always)
        main_menu()
        preview_errors()
        project_window()
        PushStyleVar(ImGuiStyleVar.ItemSpacing, float2(0.))
        SameLine()
        imgui::PopStyleVar(1)
        let sz = GetItemRectSize()
        VerticalSeparator("left_side", LEFT_SIDE_PANNEL_WIDTH)
        PushStyleVar(ImGuiStyleVar.ChildBorderSize, 0.)
        let editing = GetSelectedObjectCount() != 0
        var nedw = IO.DisplaySize.x - 10. - sz.x - 10.
        if (editing) {
            nedw -= RIGHT_SIDE_PANNEL_WIDTH
        }
        BeginChild("Node editor window", float2(nedw, -FLT_MIN), ImGuiChildFlags.Border, ImGuiWindowFlags.NoBackground)
        if (length(g_CurrentProject.actions) > 0) {
            if (BeginTabBar("##Tabs", ImGuiTabBarFlags.None)) {
                if (BeginTabItem("Project")) {
                    g_CurrentAction = ""
                    editor_child_window()
                    EndTabItem()
                }
                for (actid, actname in keys(g_CurrentProject.actions), values(g_CurrentProject.actions)) {
                    if (BeginTabItem("{actname}##{actid}")) {
                        g_CurrentAction = actid
                        editor_child_window()
                        EndTabItem()
                    }
                }
                EndTabBar()
            }
        } else {
            g_CurrentAction = ""
            editor_child_window()
        }
        EndChild()
        imgui::PopStyleVar(1)
        if (editing) {
            PushStyleVar(ImGuiStyleVar.ItemSpacing, float2(0.))
            SameLine()
            imgui::PopStyleVar(1)
            VerticalSeparator("right_side", RIGHT_SIDE_PANNEL_WIDTH, -1.)
            properties_window()
        }
        post_invoke_que()
    }
}

[export, pinvoke]
def main {
    g_CurrentProject = new Project()
    g_PreviewUpdater = @@ {
        eval_project()
    }
    seal_instruction_factory()          // initialize everything greyprint related
    init_opengl_cache()
    imgui_app("Greyprint") <| $() {
        NewFrame()
        main_editor_screen()
        Render()
        clear_text_buffers()
    }
    if (g_Context != null) {
        SetCurrentEditor(null)
        DestroyEditor(g_Context)
    }
}

// options log_mem
// options log_debug_mem

