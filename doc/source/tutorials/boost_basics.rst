.. _tutorial_boost_basics:

####################
Boost basics
####################

The smallest end-to-end dasImgui v2 program. One window, one slider, one button.
The slider drives a float (``VOLUME.value``) and the button accumulates a click
counter (``BUMP_BTN.click_count``). Both pieces of state are auto-generated
daslang globals; nothing is stored inside Dear ImGui.

Source: ``examples/tutorial/boost_basics.das``.

************
Walkthrough
************

.. image:: ../_static/tutorials/boost_basics.apng
   :alt: boost_basics recording

.. literalinclude:: ../../../examples/tutorial/boost_basics.das
   :language: das
   :linenos:

Requires
========

The ``require`` block pulls in:

* The C++-bound Dear ImGui surface (``imgui``, ``imgui_app``).
* The GLFW backend + OpenGL renderer + live-reload host glue (``glfw/...``,
  ``opengl/...``, ``live/...``).
* The dasImgui v2 boost layer: ``imgui_live`` (lifecycle), ``imgui_boost_runtime``
  (state structs), ``imgui_boost_v2`` (macros), ``imgui_widgets_builtin`` (the
  actual widget implementations).

Init and shutdown
=================

``init()`` opens a 640x320 GLFW window via ``live_create_window`` and
hands its handle to ``live_imgui_init`` so the ImGui context, fonts, and GL
backend get wired up. ``shutdown()`` reverses the pair in shutdown order.

The frame loop
==============

``update()`` is what runs every frame. The pattern, line by line:

#. ``live_begin_frame()`` — return early if the window is closing.
#. ``begin_frame()`` — boost-side per-frame setup (registry, command dispatch).
#. ``ImGui_ImplOpenGL3_NewFrame`` / ``ImGui_ImplGlfw_NewFrame`` / ``NewFrame`` —
   the standard ImGui backend prologue.
#. The widget block (see below).
#. ``end_of_frame()`` / ``Render()`` — boost-side bookkeeping, then ImGui
   composes the draw list.
#. ``glViewport`` / ``glClear`` / ``ImGui_ImplOpenGL3_RenderDrawData`` — paint.
#. ``live_end_frame()`` — swap buffers, advance live-reload housekeeping.

Widgets
=======

Two boost macros do the actual work:

.. code-block:: das

   VOLUME.bounds = (0.0f, 1.0f)
   slider_float(VOLUME, (text = "Volume"))
   Text("volume = {VOLUME.value}")

The macro form ``slider_float(VOLUME, ...)`` declares a module global
``VOLUME : SliderStateFloat`` the first time it expands. Telemetry registers it
under that name; the bounds line is plain assignment to the struct field.

.. code-block:: das

   if (button(BUMP_BTN, (text = "Bump"))) {
       print("bump clicked\n")
   }
   Text("bumps = {BUMP_BTN.click_count}")

``button(BUMP_BTN, ...)`` returns ``true`` on the frame the click registers; the
underlying ``ButtonState`` keeps ``click_count`` updated for later assertions
(e.g. from ``imgui_playwright``).

Standalone vs live
==================

``main()`` runs the loop directly when invoked as ``daslang.exe boost_basics.das``.
Under ``daslang-live`` the host calls ``init`` / ``update`` / ``shutdown``
itself; ``main`` is ignored. The slider and button states preserve across live
reloads because every boost-generated global carries ``@live`` by default.

Driving from outside
====================

When run live, the boost layer exposes the standard live-command surface at
``localhost:9090``. Mutate the slider:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_set","args":{"target":"VOLUME","value":0.75}}' \
        localhost:9090/command

…and ``VOLUME.value`` jumps to ``0.75`` on the next frame.

Next steps
==========

The next tutorial walks the full common-widget surface — text input,
slider, checkbox, combo, color, button — on a single panel.

.. seealso::

   Full source: :download:`examples/tutorial/boost_basics.das <../../../examples/tutorial/boost_basics.das>`

   Richer reference: ``examples/tutorial/visual_aids_tour.das`` — keeper
   reference exercising highlights, mouse trail, narration, and recording.

   Next tutorial: :ref:`tutorial_widgets_tour`

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.

   :ref:`Builtin widgets <stdlib_imgui_widgets_section>` — widget reference.
