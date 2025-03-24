options gen2
options indenting = 4

module instructions_ui

require instructions public
require preview
require undo_stack

require rtti
require imgui/imgui_boost public
require glfw/glfw_boost
require daslib/safe_addr
require math
require stddlg
require strings

let DEFAULT_NODE_WIDTH  = 500.
let DEFAULT_ELEMENT_WIDTH = DEFAULT_NODE_WIDTH - 20.
let DEFAULT_NAMED_ELEMENT_WIDTH = DEFAULT_NODE_WIDTH - 20.

// text buffers

var g_InputTextBuffers : array<ImGuiInputTextBuffer?>

def get_next_text_buffer(txt : string; maxlen : int = 128) {
    var buf = new ImGuiInputTextBuffer(txt, maxlen)
    g_InputTextBuffers |> push(buf)
    return buf
}

def clear_text_buffers {
    delete g_InputTextBuffers
}

// editing

def NodeTextMultiline(mode : EditMode; id, name : string; var text : string&; maxlen : int = 128) {
    var buf = get_next_text_buffer(text, maxlen)
    Text(name)
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH)
    if (InputTextMultiline("##{name}{id}{mode}_Text", *buf, float2(0))) {
        text = to_string(*buf)
        undo_edit_instruction(id, name)
        update_preview()
    }
}

def NodeText(mode : EditMode; id, name : string; var text : string&; maxlen : int = 128) {
    var buf = get_next_text_buffer(text, maxlen)
    Text(name)
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH)
    if (InputText("##{name}{id}{mode}_Text", *buf)) {
        text = to_string(*buf)
        undo_edit_instruction(id, name)
        update_preview()
    }
}

def NodeArgumentName(mode : EditMode; id, name : string; var text : string&; var proj : Project?; maxlen : int = 128) {
    var buf = get_next_text_buffer(text, maxlen)
    Text(name)
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH)
    if (InputText("##{name}{id}{mode}_Text", *buf)) {
        text = to_string(*buf)
        proj->sync()
        undo_edit_instruction(id, name)
        update_preview()
    }
}

def NodeEditEnumeration(mode : EditMode; id, name : string; var op : auto&) {
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH)
    Text(name)
    if (ListBox("{name}##{id}{mode}_Enumeration", op)) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeColorEditor4(mode : EditMode; id, name : string; var data : float4&) {
    Dummy(float2(DEFAULT_ELEMENT_WIDTH - CalcTextSize(name).x, 0.))
    SameLine()
    Text(name)
    SetNextItemWidth(DEFAULT_ELEMENT_WIDTH - 50.)
    var flags = ImGuiColorEditFlags.AlphaBar
    if (mode == EditMode.Embedded) {
        flags |= ImGuiColorEditFlags.NoTooltip | ImGuiColorEditFlags.NoOptions
    }
    if (ColorPicker4("##{name}{id}{mode}_ColorEditor4", unsafe(addr(data.x)), flags)) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeInputInt(mode : EditMode; id, name : string; var data : int&) {
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH - CalcTextSize(name).x)
    if (InputInt("{name}##{id}{mode}_InputInt", unsafe(addr(data)))) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeInputInt2(mode : EditMode; id, name : string; var data : int2&) {
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH - CalcTextSize(name).x)
    if (InputInt2("{name}##{id}{mode}_InputInt2", unsafe(addr(data.x)))) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeDragFloat(mode : EditMode; id, name : string; var data : float&; step : float = 0.01f) {
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH - CalcTextSize(name).x)
    if (DragFloat("{name}##{id}{mode}_DragFloat", unsafe(addr(data)), step)) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeDragFloat2(mode : EditMode; id, name : string; var data : float2&; step : float = 0.01f) {
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH - CalcTextSize(name).x)
    var any = DragFloat("{name}.x##{id}{mode}_DragFloat_x", unsafe(addr(data.x)), step)
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH - CalcTextSize(name).x)
    any = DragFloat("{name}.y##{id}{mode}_DragFloat_y", unsafe(addr(data.y)), step) || any
    if (any) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeCheckbox(mode : EditMode; id, name : string; var data : bool&) {
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH -  -CalcTextSize(name).x)
    if (Checkbox("{name}##{id}{mode}_Checkbox", unsafe(addr(data)))) {
        undo_edit_instruction(id, name)
        update_preview()
        return true
    } else {
        return false
    }
}

def NodeFileName(mode : EditMode; id, name : string; var text : string&) {
    var buf = get_next_text_buffer(text, 256)
    if (Button("...##{name}{id}{mode}_Button")) {
        let fname = get_dlg_open_file(text, "png|jpg|tga")  // todo: filter supported only
        if (!empty(fname)) {
            text = fname
            undo_edit_instruction(id, name)
            update_preview()
        }
    }
    SameLine()
    SetNextItemWidth(DEFAULT_NAMED_ELEMENT_WIDTH - GetCursorPosX() - 8.)
    Text(text)
}
