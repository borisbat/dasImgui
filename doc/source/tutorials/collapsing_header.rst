.. _tutorial_collapsing_header:

#######################
Collapsing header
#######################

``collapsing_header`` is the section-fold sibling of ``tree_node``: same
expand/collapse chevron, but **no** ``TreePop`` pair — ImGui owns the
close lifecycle. Two distinct gates govern visibility:

* **Expanded** — the chevron click toggles the body. ``state.opened`` is
  the per-frame ``CollapsingHeader`` return value.
* **Closable** — with ``closable=true``, ImGui adds an X-button that
  sets ``state.open=false``. While ``state.open`` is false, **the whole
  header strip is hidden** (not just its body).

The boost wrapper exposes both gates via the standard
``pending_open`` / ``pending_close`` flags, so the live commands
``imgui_open`` / ``imgui_close`` work on either dimension.

Source: ``examples/tutorial/collapsing_header.das``.

************
Walkthrough
************

.. image:: ../_static/tutorials/collapsing_header.apng
   :alt: collapsing_header recording

.. literalinclude:: ../../../examples/tutorial/collapsing_header.das
   :language: das
   :linenos:

Requires
========

Already in the baseline boost layer:

* ``imgui/imgui_containers_builtin`` — ``collapsing_header``.
* ``imgui/imgui_widgets_builtin`` — ``text``, ``checkbox``, ``slider_int``.

Two visibility dimensions
=========================

``CollapsingHeaderState`` carries both gates:

.. code-block:: das

   var CLOSABLE_CH : CollapsingHeaderState
   // After the frame renders:
   //   CLOSABLE_CH.open    : bool   // X-button gate (visible at all?)
   //   CLOSABLE_CH.opened  : bool   // chevron gate (body expanded?)
   //   CLOSABLE_CH.flags   : ImGuiTreeNodeFlags   // sticky

``open`` is the X-button channel. ``opened`` is the chevron channel.
Both surface in the snapshot. Tests that want to verify "the user
expanded the section but didn't close it" check ``opened==true &&
open==true``.

The closable form
=================

When ``closable=true``, ``ImGui::CollapsingHeader`` takes a
``bool* p_visible`` and renders an X-button on the right of the header
strip. The boost wrapper feeds ``&state.open`` to that pointer:

.. code-block:: das

   collapsing_header(CLOSABLE_CH, (text = "Closable header",
                                   closable = true,
                                   flags = ImGuiTreeNodeFlags.DefaultOpen)) {
       text("X-button on the right of the header strip closes this section.")
       // body
   }

Click the X — ImGui sets ``state.open=false``. Next frame, the
wrapper sees ``open==false`` and **skips the ImGui call entirely**.
The header row is gone until something flips ``open`` back to true.
That something is either app code (``CLOSABLE_CH.open = true``) or a
live driver (``imgui_open`` against the path).

The pending-flag channel
========================

Two channels feed open/close from outside:

* ``state.pending_open = true`` — set anywhere in app code, then the
  next frame's call to the container clears it and applies
  ``SetNextItemOpen(true, Always)``.
* ``imgui_open`` — the live command. The dispatcher walks the
  ``ImguiPathRegistry`` and sets ``pending_open`` on the matching state.

Same shape for ``pending_close`` / ``imgui_close``. The closable form
also clears ``state.open=false`` from the X-button — three control
surfaces flow through one struct.

DefaultOpen flag
================

``ImGuiTreeNodeFlags.DefaultOpen`` makes the chevron expanded on first
render only. Subsequent frames respect whatever the user clicked.
Useful for "show me the important section by default" without
remembering open-state across runs.

.. code-block:: das

   collapsing_header(STARTUP_CH, (text = "Starts open",
                                  closable = false,
                                  flags = ImGuiTreeNodeFlags.DefaultOpen)) {
       text("Body visible on first render.")
   }

Other ``ImGuiTreeNodeFlags`` compose: ``OpenOnArrow``, ``OpenOnDoubleClick``,
``Bullet``, ``Framed``, ``Leaf`` — same flag enum as ``tree_node`` (the
two rails share semantics intentionally).

Standalone vs live
==================

Same convention as the other tutorials.

Driving from outside
====================

Both gates are driveable. To collapse-and-hide the closable header:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_close","args":{"target":"CH_WIN/CLOSABLE_CH"}}' \
        localhost:9090/command

To bring it back:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_open","args":{"target":"CH_WIN/CLOSABLE_CH"}}' \
        localhost:9090/command

A non-closable header treats ``imgui_open`` / ``imgui_close`` as
"set the chevron state" — ``state.open`` is ignored, only
``state.pending_open`` / ``pending_close`` (the chevron channel) fire.

.. seealso::

   Full source: :download:`examples/tutorial/collapsing_header.das <../../../examples/tutorial/collapsing_header.das>`

   Features-side demo: ``examples/features/collapsing_header_closable.das`` —
   minimal closable-X-button repro with integration test.

   Sibling: :ref:`tutorial_containers` — umbrella container tour.

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
