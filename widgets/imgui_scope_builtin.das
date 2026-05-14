options gen2
options indenting = 4
options no_unused_block_arguments = false

module imgui_scope_builtin shared

require imgui public
require imgui/imgui_boost_runtime public

def public with_indent(amount : float; blk : block) {
    //! Run ``blk`` with ``Indent(amount)`` applied; matching ``Unindent(amount)`` on return.
    //! Pass ``0.0f`` to defer to ImGui's ``IndentSpacing`` style default.
    Indent(amount)
    invoke(blk)
    Unindent(amount)
}

def public with_item_width(item_width : float; blk : block) {
    //! Run ``blk`` with ``PushItemWidth(item_width)`` applied; matching ``PopItemWidth()`` on return.
    //! Negative values are "right edge minus N pixels"; positive are absolute widget width.
    PushItemWidth(item_width)
    invoke(blk)
    PopItemWidth()
}

def public with_text_wrap_pos(wrap_local_pos_x : float; blk : block) {
    //! Run ``blk`` with ``PushTextWrapPos(wrap_local_pos_x)`` applied; matching ``PopTextWrapPos()`` on return.
    //! Pass ``0.0f`` to wrap at the window's right edge; positive is an x-coord in window-local space.
    PushTextWrapPos(wrap_local_pos_x)
    invoke(blk)
    PopTextWrapPos()
}
