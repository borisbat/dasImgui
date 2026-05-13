.. _tutorial_docking:

#######################
Docking
#######################

ImGui's native docking lets the user grab a window's tab and drop it into a
side pane, the bottom pane, or even pop it out to a free-floating window —
all preserved across runs through ``imgui.ini``. The dasImgui boost layer
wraps the C++ surface in two macros: ``dockspace`` (the full-viewport
dockable region) and ``dock_window`` (each dockable panel inside it). A
small ``DockBuilder`` helper seeds a 3-pane initial layout so first-run
users see something meaningful before they start dragging tabs around.

Source: ``examples/tutorial/docking.das``.

************
Walkthrough
************

.. image:: ../_static/tutorials/docking.apng
   :alt: docking recording

.. literalinclude:: ../../../examples/tutorial/docking.das
   :language: das
   :linenos:

Requires
========

Same backend + boost layer as :ref:`tutorial_layout`, but layout helpers are
replaced by the docking module:

* ``imgui/imgui_docking_builtin`` — the ``dockspace`` and ``dock_window``
  macros, plus the ``DockBuilder*`` bindings cherry-picked from ImGui's
  internal API.

The flag that lights it up
==========================

ImGui docking is gated by a single io flag. Without it, ``DockSpace`` calls
render nothing and ``dock_window`` panels behave like ordinary windows:

.. code-block:: das

   io.ConfigFlags |= ImGuiConfigFlags.DockingEnable

This goes in ``init()`` once per session.

Seeding the layout
==================

ImGui will happily start with every dockable window stacked in a single
tab-bar — the user is expected to drag tabs into place. For a tutorial we
ship a default arrangement via ``DockBuilder``:

.. code-block:: das

   DockBuilderRemoveNode(dock_id)                          // clear any prior state
   DockBuilderAddDockSpaceNode(dock_id, flags)             // fresh dockspace root
   DockBuilderSetNodeSize(dock_id, ImVec2(vp.Size.x, vp.Size.y))
   var left_id, right_id : uint
   DockBuilderSplitNode(dock_id, ImGuiDir.Left, 0.25f, left_id, right_id)
   var top_id, bottom_id : uint
   DockBuilderSplitNode(right_id, ImGuiDir.Up, 0.6f, top_id, bottom_id)
   DockBuilderDockWindow("Explorer", left_id)
   DockBuilderDockWindow("Source",   top_id)
   DockBuilderDockWindow("Output",   bottom_id)
   DockBuilderFinish(dock_id)

``DockBuilderDockWindow`` matches by window *title string* — the same string
you pass to ``dock_window(NAME, (text = "Explorer"))``. The boost macro
doesn't auto-derive the title from the identifier so the binding is
explicit.

The setup is gated on ``state.has_initial_layout`` so it runs once per
session — or after ``imgui_dock_reset`` flips the flag back to false.

The frame loop
==============

The ``dockspace(DOCK_ROOT, ...)`` macro wraps ``DockSpaceOverViewport`` —
the dock region is the entire OS window. Inside its block, each
``dock_window(NAME, ...)`` is a Begin/End-wrapped panel that participates
in the docking system. Path-prefixing works the same as containers
(``window`` / ``child`` / ``tab_bar``): ``dock_window(EXPLORER) {
button(REFRESH_BTN, ...) }`` registers the button under
``DOCK_ROOT/EXPLORER/REFRESH_BTN``.

The ``closable = true`` option (on ``OUTPUT`` here) wires the X-button in
the tab to ``state.open`` — closing the panel without rebuilding the
layout.

Standalone vs live
==================

Same as previous tutorials — ``main()`` runs the loop standalone;
``daslang-live`` invokes ``init`` / ``update`` / ``shutdown`` directly.
ImGui's docking state is preserved across reloads because the ImGui
context survives reload (``imgui_live`` serializes the context pointer
through the reload, and the dock state lives inside that context).

Driving from outside
====================

Three live commands cover the docking surface. Targets are
path-qualified — the dockspace pushes its name onto the path, so panel
targets are ``DOCK_ROOT/<name>``:

.. code-block:: bash

   # Pop Output out into a floating window
   curl -X POST -d '{"name":"imgui_undock","args":{"target":"DOCK_ROOT/OUTPUT"}}' \
        localhost:9090/command

   # Reset the dockspace back to the default layout
   curl -X POST -d '{"name":"imgui_dock_reset","args":{"target":"DOCK_ROOT"}}' \
        localhost:9090/command

   # Close the OUTPUT panel (X-button equivalent — closable=true required)
   curl -X POST -d '{"name":"imgui_close","args":{"target":"DOCK_ROOT/OUTPUT"}}' \
        localhost:9090/command

``imgui_dock`` is the inverse of ``imgui_undock`` — it takes a ``value`` of
type ``uint`` (a dock-node id from a prior ``DockBuilder*`` call) and
re-docks the panel into that node.

Next steps
==========

Style scopes are next — pushing colors and metrics for a sub-tree of
widgets, plus the ``(text_color = ...)`` sugar.

.. seealso::

   Full source: :download:`examples/tutorial/docking.das <../../../examples/tutorial/docking.das>`

   Richer reference: ``examples/features/dock_basic.das`` — same boost
   surface with a 4-panel initial layout and a wider widget set.

   Integration test: ``tests/integration/test_docking_basic.das`` —
   registration, initial-layout geometry, and live-command round-trips.

   Previous tutorial: :ref:`tutorial_layout`

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
