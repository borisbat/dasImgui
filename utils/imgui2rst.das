options gen2
options rtti = true

require daslib/fio
require daslib/rtti
require daslib/ast
require daslib/rst_comment
require daslib/rst
require daslib/regex
require daslib/regex_boost
require daslib/profiler_boost

// pull in every v2 module so RTTI can see them. (v1 daslib/imgui_boost is excluded.)
require imgui/imgui_boost_v2
require imgui/imgui_boost_runtime
require imgui/imgui_containers_builtin
require imgui/imgui_id_builtin
require imgui/imgui_layout_builtin
require imgui/imgui_live
require imgui/imgui_live_core
require imgui/imgui_playwright
require imgui/imgui_style_builtin
require imgui/imgui_transport
require imgui/imgui_visual_aids
require imgui/imgui_widgets_builtin


def document_module_imgui_boost_v2(root : string) {
    var mod = find_module("imgui_boost_v2")
    var groups <- array<DocGroup>(
        group_by_regex("Container macros",       mod, %regex~^(window|child|group|tab_bar|tab_item|menu_bar|menu|popup|modal|tree_node|collapsing_header)$%%),
        group_by_regex("Widget annotation macros", mod, %regex~^(define_widget|widget|container)$%%),
        group_by_regex("ID scope macros",        mod, %regex~^(with_id|with_path)$%%),
        group_by_regex("Style scope macros",     mod, %regex~^(with_style|with_color|with_var)$%%),
        group_by_regex("Layout macros",          mod, %regex~^(split_h|split_v|columns|dock_left|dock_right|dock_top|dock_bottom)$%%),
        hide_group(group_by_regex("Internal",    mod, %regex~^(_|priv_).*%%))
    )
    document("Boost macro layer — DSL for declarative widget composition", mod, "imgui_boost_v2.rst", groups)
}

def document_module_imgui_boost_runtime(root : string) {
    var mod = find_module("imgui_boost_runtime")
    var groups <- array<DocGroup>(
        group_by_regex("Widget state types",      mod, %regex~.*State(Float|Int|Float2|Float3|Float4|Int2|Int3|Int4)?$%%),
        group_by_regex("Per-frame registry",      mod, %regex~^(WidgetEntry|WidgetMeta|begin_frame|end_frame|register_widget|lookup_widget).*%%),
        group_by_regex("Live commands",           mod, %regex~^imgui_(snapshot|click|set|open|close|focus|await|drag|type_text)$%%),
        group_by_regex("Await modifiers",         mod, %regex~^(AwaitModifiers|AwaitArgs|AwaitResult|with_await)$%%),
        group_by_regex("JSON serialization",      mod, %regex~^(widget_entry_jv|to_JV|from_JV).*%%),
        hide_group(group_by_regex("Internal",     mod, %regex~^(_|priv_).*%%))
    )
    document("Boost runtime — widget state structs, registry, and dispatcher", mod, "imgui_boost_runtime.rst", groups)
}

def document_module_imgui_widgets_builtin(root : string) {
    var mod = find_module("imgui_widgets_builtin")
    var groups <- array<DocGroup>(
        group_by_regex("Buttons",         mod, %regex~^(button|small_button|arrow_button|image_button|invisible_button|checkbox|radio_button)$%%),
        group_by_regex("Sliders",         mod, %regex~^(slider|slider_int|slider_float|slider_int2|slider_int3|slider_int4|slider_float2|slider_float3|slider_float4|slider_angle)$%%),
        group_by_regex("Drag inputs",     mod, %regex~^drag.*%%),
        group_by_regex("Text input",      mod, %regex~^(input_text|input_text_multiline|input_int|input_float|input_int2|input_int3|input_int4|input_float2|input_float3|input_float4)$%%),
        group_by_regex("Color pickers",   mod, %regex~^(color_edit|color_picker|color_button)$%%),
        group_by_regex("Selection",       mod, %regex~^(combo|list_box|selectable)$%%),
        group_by_regex("Plot helpers",    mod, %regex~^(plot_lines|plot_histogram|progress_bar)$%%),
        group_by_regex("Output",          mod, %regex~^(text_show|text_input|label_text|bullet_text|help_marker)$%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("Built-in widgets — inputs, selection, color, plots, output", mod, "imgui_widgets_builtin.rst", groups)
}

def document_module_imgui_containers_builtin(root : string) {
    var mod = find_module("imgui_containers_builtin")
    var groups <- array<DocGroup>(
        group_by_regex("Windows",       mod, %regex~^(window|child|group)$%%),
        group_by_regex("Tabs",          mod, %regex~^(tab_bar|tab_item)$%%),
        group_by_regex("Trees",         mod, %regex~^(tree_node|collapsing_header)$%%),
        group_by_regex("Menus",         mod, %regex~^(menu_bar|menu|menu_item)$%%),
        group_by_regex("Popups",        mod, %regex~^(popup|modal|tooltip)$%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("Built-in containers — windows, child regions, tabs, menus, popups", mod, "imgui_containers_builtin.rst", groups)
}

def document_module_imgui_id_builtin(root : string) {
    var mod = find_module("imgui_id_builtin")
    var groups <- array<DocGroup>(
        group_by_regex("ID stack",      mod, %regex~^(push_id|pop_id|with_id|with_path)$%%),
        group_by_regex("Hashing",       mod, %regex~^(hash_id|get_id).*%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("ID stack — push/pop, scoped, hashing", mod, "imgui_id_builtin.rst", groups)
}

def document_module_imgui_layout_builtin(root : string) {
    var mod = find_module("imgui_layout_builtin")
    var groups <- array<DocGroup>(
        group_by_regex("Splits",        mod, %regex~^split_.*%%),
        group_by_regex("Columns",       mod, %regex~^columns$%%),
        group_by_regex("Dock helpers",  mod, %regex~^dock_.*%%),
        group_by_regex("Spacing",       mod, %regex~^(same_line|spacing|new_line|separator|indent|unindent)$%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("Layout helpers — splits, columns, docking, spacing", mod, "imgui_layout_builtin.rst", groups)
}

def document_module_imgui_style_builtin(root : string) {
    var mod = find_module("imgui_style_builtin")
    var groups <- array<DocGroup>(
        group_by_regex("Style scope",   mod, %regex~^(with_style|with_color|with_var)$%%),
        group_by_regex("Push/pop",      mod, %regex~^(push_style|pop_style).*%%),
        group_by_regex("Themes",        mod, %regex~^(style_colors_dark|style_colors_light|style_colors_classic)$%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("Style helpers — colors, vars, push/pop, themes", mod, "imgui_style_builtin.rst", groups)
}

def document_module_imgui_visual_aids(root : string) {
    var mod = find_module("imgui_visual_aids")
    var groups <- array<DocGroup>(
        group_by_regex("Highlight overlay", mod, %regex~^(imgui_highlight|highlight|paint_highlight).*%%),
        group_by_regex("Mouse trail",       mod, %regex~^(imgui_mouse_trail|mouse_trail|paint_mouse_trail).*%%),
        group_by_regex("Narration",         mod, %regex~^(narrate|paint_narrate|paint_callout).*%%),
        group_by_regex("HUD",               mod, %regex~^(paint_key_hud|glyph_for_imgui_key|paint_hud).*%%),
        group_by_regex("Serve / lifecycle", mod, %regex~^(imgui_visual_aids_serve|render_visual_aids|effective_).*%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("Visual aids — tutorial-mode overlays, mouse trail, narration, key HUD", mod, "imgui_visual_aids.rst", groups)
}

def document_module_imgui_playwright(root : string) {
    var mod = find_module("imgui_playwright")
    var groups <- array<DocGroup>(
        group_by_regex("App lifecycle",     mod, %regex~^(with_imgui_app|launch_imgui_app|shutdown).*%%),
        group_by_regex("Locators / queries", mod, %regex~^(find_widget|widget_exists|widget_payload_field|widget_rendered)$%%),
        group_by_regex("Actions",           mod, %regex~^(click|type_text|set_value|drag|focus|open_widget|close_widget|reload)$%%),
        group_by_regex("Snapshots",         mod, %regex~^(snapshot|expect_value|expect_render).*%%),
        group_by_regex("Polling / await",   mod, %regex~^(wait_until|wait_for_payload_value|await_quiescent|await_probe)$%%),
        group_by_regex("Transport plumbing", mod, %regex~^(post_command|send_imgui_command|receive_imgui_command).*%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    document("Playwright — block-form test harness for daslang-live + dasImgui apps", mod, "imgui_playwright.rst", groups)
}

def document_module_imgui_live(root : string) {
    var mod = [find_module("imgui_live"), find_module("imgui_live_core")]
    var groups <- array<DocGroup>(
        group_by_regex("Lifecycle",           mod, %regex~^(live_imgui_init|live_imgui_shutdown|live_imgui_.*)$%%),
        group_by_regex("Synth IO drivers",    mod, %regex~^(synth_|imgui_mouse_|imgui_key_|imgui_synth_).*%%),
        group_by_regex("Event timelines",     mod, %regex~^(MouseEventWire|KeyEventWire|sort_mouse_play_events|.*_play)$%%),
        group_by_regex("Override hooks",      mod, %regex~^(apply_synth_io_override|effective_cursor_pos|effective_synth_click)$%%),
        group_by_regex("Status / introspection", mod, %regex~^(.*_status|.*Status).*%%),
        hide_group(group_by_regex("Internal", mod, %regex~^(_|priv_).*%%))
    )
    documents("Live-reload lifecycle and synthetic-IO bypass driver",
              mod, "imgui_live.rst", groups)
}

def document_module_imgui_transport(root : string) {
    var mod = find_module("imgui_transport")
    var groups <- array<DocGroup>(
        group_by_regex("Transport construction", mod, %regex~^(live_api_transport|make_transport|with_transport)$%%),
        group_by_regex("Send / receive",         mod, %regex~^(send_imgui_command|receive_imgui_command|post_command)$%%),
        group_by_regex("Framing / encoding",     mod, %regex~^(encode_|decode_|frame_).*%%),
        hide_group(group_by_regex("Internal",    mod, %regex~^(_|priv_).*%%))
    )
    document("Transport — pluggable lambda-based IPC for imgui commands", mod, "imgui_transport.rst", groups)
}


[export]
def main {
    disable_profiler(this_context())
    disable_profiler_log(this_context())
    ast_gc_guard() {
        let dasimgui_doc = get_das_root() + "/modules/dasImgui/doc/source/stdlib"
        topic_root = "{dasimgui_doc}/generated"
        handmade_root = dasimgui_doc
        
        let root = topic_root
        document_module_imgui_boost_v2(root)
        document_module_imgui_boost_runtime(root)
        document_module_imgui_widgets_builtin(root)
        document_module_imgui_containers_builtin(root)
        document_module_imgui_id_builtin(root)
        document_module_imgui_layout_builtin(root)
        document_module_imgui_style_builtin(root)
        document_module_imgui_visual_aids(root)
        document_module_imgui_playwright(root)
        document_module_imgui_live(root)
        document_module_imgui_transport(root)
    }
}
