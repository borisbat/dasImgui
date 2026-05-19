options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``data_table.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_data_table.das

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    with_recording_app("examples/tutorial/data_table.das",
                       "data_table.apng", 30) $(app) {
        // Window-prefixed registry paths for the cells we'll narrate.
        let T_TABLE = "DT_WIN/DT_TABLE"
        let T_NAME0 = "DT_WIN/DT_TABLE/DT_NAME[0]"
        let T_KIND2 = "DT_WIN/DT_TABLE/DT_KIND[2]"
        let T_VAL5  = "DT_WIN/DT_TABLE/DT_VAL[5]"

        var snap = wait_for_render(app, T_NAME0, 10.0f)
        if (snap == null) {
            panic("{T_NAME0} never rendered — wrong app running?")
        }
        let p_table = widget_center(snap, T_TABLE)
        let p_name0 = widget_center(snap, T_NAME0)
        let p_kind2 = widget_center(snap, T_KIND2)
        let p_val5  = widget_center(snap, T_VAL5)

        // ---- Stage 1: announce the container ----
        post_command(app, "imgui_narrate", JV((
            text = "data_table — container for ImGui BeginTable/EndTable.",
            target = T_TABLE,
            frames = 180
        )))
        move_to(app, p_table)
        sleep(3500u)

        // ---- Stage 2: per-cell visit (Name col → Type col → Value col) ----
        post_command(app, "imgui_narrate", JV((
            text = "table_set_column_index(0) jumps to the Name column.",
            target = T_NAME0,
            frames = 180
        )))
        move_to(app, p_name0)
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "table_set_column_index(1) jumps to the Type column.",
            target = T_KIND2,
            frames = 180
        )))
        move_to(app, p_kind2)
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "table_set_column_index(2) jumps to the Value column.",
            target = T_VAL5,
            frames = 180
        )))
        move_to(app, p_val5)
        sleep(3500u)

        // ---- Stage 5: sort_specs — point at the Name column ----
        // Recorder only moves the cursor; no synthesized header click. The
        // narration describes the API rather than demonstrating an actual
        // sort interaction.
        post_command(app, "imgui_narrate", JV((
            text = "sort_specs() captures column user_ids when ImGui reports SpecsDirty (try clicking a header live).",
            target = T_NAME0,
            frames = 180
        )))
        move_to(app, p_name0)
        sleep(3500u)

        // ---- Stage 6: SortMulti — point at a secondary column ----
        post_command(app, "imgui_narrate", JV((
            text = "SortMulti lets Shift+click append a secondary sort key — try it live.",
            target = T_KIND2,
            frames = 180
        )))
        move_to(app, p_kind2)
        sleep(3500u)
    }
}
