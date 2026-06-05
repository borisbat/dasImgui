options gen2
options indenting = 4
options no_unused_block_arguments = false

module imgui_id_builtin shared

require imgui public
require imgui/imgui_boost_runtime public

def public with_id(s : string; blk : block) {
    //! Run ``blk`` with ``s`` pushed onto ImGui's ID stack and the boost container-path; both pop on return.
    //! Reach for this only when the indexed-widget form (``IDENT[i]``) can't — composed helpers, data-driven structure. API_REWORK §4.8.
    container_path_push(s)
    PushID(s)
    invoke(blk)
    PopID()
    container_path_pop()
}

def public with_override_id(id : uint; blk : block) {
    //! Run ``blk`` with raw ``id`` pushed via ``PushOverrideID`` (as-is, NOT
    //! hash-combined like ``with_id``), popped on return. For stable, explicitly
    //! controlled IDs — custom widgets, addressing into ImGuiStorage, or seeding a
    //! string ID (``GetID`` under the override equals ``GetIDWithSeed(.., id)``).
    container_path_push("{id}")
    PushOverrideID(id)
    invoke(blk)
    PopID()
    container_path_pop()
}
