options gen2
options indenting = 4

module imgui_enums shared

require imgui

//! Flag-operator extensions for imgui enums the binder couldn't give flag-ops to.
//!
//! The binder generates ``|`` / ``&`` (C++ ``addEnumFlagOps``) only for PUBLIC flag
//! typedefs — it maps ``typedef int ImGuiXxxFlags`` to the matching ``ImGuiXxxFlags_``
//! enum and attaches the ops. Enums pulled from ``imgui_internal.h`` (currently
//! ``ImGuiItemFlags``) have no such public typedef, so they bind as a plain enum with
//! no bitwise operators. These explicit overloads restore them, so internal flag enums
//! combine like the public ones:
//!
//!   ``with_item_flag(ImGuiItemFlags.AllowOverlap | ImGuiItemFlags.NoNav, true) { ... }``
//!
//! The enum is int-backed, so each op reinterprets the int result back to the enum.

def public operator |(a, b : ImGuiItemFlags) : ImGuiItemFlags {
    //! Bitwise OR — combine item flags into a single push.
    // PERF019 can't collapse int(a)|int(b) to int(a|b) here: a|b IS this operator.
    return unsafe(reinterpret<ImGuiItemFlags>(int(a) | int(b))) // nolint:PERF019
}

def public operator &(a, b : ImGuiItemFlags) : ImGuiItemFlags {
    //! Bitwise AND — mask / membership test (pair with ``bool``/``!`` from enum_trait).
    return unsafe(reinterpret<ImGuiItemFlags>(int(a) & int(b))) // nolint:PERF019
}

def public operator ~(a : ImGuiItemFlags) : ImGuiItemFlags {
    //! Bitwise complement — clear-mask for ``flags & ~ImGuiItemFlags.X``.
    return unsafe(reinterpret<ImGuiItemFlags>(~int(a)))
}
