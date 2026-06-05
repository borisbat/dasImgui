options gen2
options indenting = 4
options no_unused_block_arguments = false

module imgui_scope_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_enums public

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

def public with_disabled(disabled : bool; blk : block) {
    //! Run ``blk`` with ``BeginDisabled(disabled)`` applied; matching ``EndDisabled()`` on return.
    //! While ``disabled=true`` every widget inside ``blk`` is rendered greyed-out and ignores input.
    BeginDisabled(disabled)
    invoke(blk)
    EndDisabled()
}

def public with_font(font : ImFont?; blk : block) {
    //! Run ``blk`` with ``PushFont(font)`` applied; matching ``PopFont()`` on return.
    //! ``font`` is typically obtained from the font atlas (e.g. ``GetIO().Fonts.Fonts[i]``).
    PushFont(font)
    invoke(blk)
    PopFont()
}

def public with_button_repeat(repeat : bool; blk : block) {
    //! Run ``blk`` with ``PushButtonRepeat(repeat)`` applied; matching ``PopButtonRepeat()`` on return.
    //! When ``repeat=true``, held-down buttons fire repeated click events at the io.KeyRepeatRate cadence.
    PushButtonRepeat(repeat)
    invoke(blk)
    PopButtonRepeat()
}

def public with_clip_rect(clip_rect_min : float2; clip_rect_max : float2;
                          intersect_with_current : bool; blk : block) {
    //! Run ``blk`` with ``PushClipRect(min, max, intersect)`` applied; matching ``PopClipRect()`` on return.
    //! When ``intersect_with_current=true`` the new rect is intersected with the existing clip rect;
    //! otherwise it replaces it. Coordinates are in screen space.
    PushClipRect(clip_rect_min, clip_rect_max, intersect_with_current)
    invoke(blk)
    PopClipRect()
}

def public with_tab_stop(tab_stop : bool; blk : block) {
    //! Run ``blk`` with ``PushTabStop(tab_stop)`` applied; matching ``PopTabStop()`` on return.
    //! When ``tab_stop=false`` every widget inside ``blk`` is skipped by TAB / Shift+Tab focus cycling.
    PushTabStop(tab_stop)
    invoke(blk)
    PopTabStop()
}

def public with_item_flag(flag : ImGuiItemFlags; enabled : bool; blk : block) {
    //! Run ``blk`` with ``PushItemFlag(flag, enabled)`` applied; matching ``PopItemFlag()`` on return.
    //! For internal item flags lacking a dedicated guard (``AllowOverlap``, ``NoNav``, ``MixedValue``, ``ReadOnly``).
    PushItemFlag(int(flag), enabled)
    invoke(blk)
    PopItemFlag()
}

def public with_focus_scope(id : uint; blk : block) {
    //! Run ``blk`` inside focus scope ``id`` (``PushFocusScope``); matching ``PopFocusScope()`` on return.
    //! Focus scopes group items for keyboard/gamepad nav and multi-select; ``id`` is a raw ImGuiID (e.g. ``GetID("list")``).
    PushFocusScope(id)
    invoke(blk)
    PopFocusScope()
}
