.. _stdlib_imgui_external_types_section:

***************
External types
***************

Types defined by C++-bound sister modules (``imgui`` core bindings, ``dasGLFW``)
that dasImgui references but does not own. Until those modules ship their own
Sphinx sites and an intersphinx bridge, this page anchors the labels so the
generated module pages can link without dangling references.

.. _enum-imgui-ImGuiCol:

``imgui::ImGuiCol``
===================

Style-color enum exposed by the ``imgui`` builtin module (the C++ Dear ImGui
binding layer). Indexes a slot in the active style's color table — passed to
:ref:`push_style_one <function-imgui_style_builtin_push_style_one_ImGuiCol_uint>`,
``push_style_color``, ``pop_style_color``, and friends. Values map directly to
upstream ``ImGuiCol_*`` enumerants (``Text``, ``WindowBg``, ``Button``, …); see
the `Dear ImGui ImGuiCol_ reference <https://github.com/ocornut/imgui/blob/master/imgui.h>`_
for the full enumerator list.

.. _enum-imgui-ImGuiWindowFlags:
.. _enum-imgui-ImGuiChildFlags:
.. _enum-imgui-ImGuiTabBarFlags:
.. _enum-imgui-ImGuiTabItemFlags:
.. _enum-imgui-ImGuiTreeNodeFlags:
.. _enum-imgui-ImGuiPopupFlags:

``imgui::ImGui*Flags``
======================

Bitfield enums exposed by the ``imgui`` builtin module: ``ImGuiWindowFlags``,
``ImGuiChildFlags``, ``ImGuiTabBarFlags``, ``ImGuiTabItemFlags``,
``ImGuiTreeNodeFlags``, ``ImGuiPopupFlags``. Passed to the corresponding
``imgui::Begin*`` / ``BeginTabBar`` / ``BeginTabItem`` / ``TreeNodeEx`` /
``OpenPopup`` calls. Values map directly to upstream ``ImGui*Flags_*``
enumerants; see the
`Dear ImGui flag enums <https://github.com/ocornut/imgui/blob/master/imgui.h>`_
for the full enumerator lists.

.. _handle-glfw-GLFWwindow:

``glfw::GLFWwindow``
====================

Opaque GLFW window handle exposed by the ``dasGLFW`` sister module. Passed
through the live-reload host's window lifecycle (creation, swap, event drain)
and forwarded into ImGui's GLFW backend. See the
`GLFW documentation <https://www.glfw.org/docs/latest/group__window.html>`_
for the handle's C-side semantics.
