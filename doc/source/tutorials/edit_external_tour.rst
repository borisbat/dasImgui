.. _tutorial_edit_external_tour:

#################################
External-pointer editing rail
#################################

State-managed boost widgets (``slider_float``, ``checkbox``, ``combo``,
…) auto-emit a per-call global state struct that owns ``.value``.
That's fine for new code, but doesn't help when the data already lives
in someone else's struct, a daslang global, or a C-side configuration
block.

The ``edit_*`` family takes a caller-owned ``T?`` pointer instead. The
widget reads + writes through that pointer; a hidden internal mirror
keeps the snapshot stable across frames.

Source: ``examples/tutorial/editing_external.das``.

.. raw:: html

   <video autoplay loop muted playsinline width="100%">
     <source src="../_static/tutorials/edit_external_tour.mp4" type="video/mp4">
     Your browser doesn't support HTML5 video. <a href="../_static/tutorials/edit_external_tour.mp4">Download the recording</a>.
   </video>

What the tour shows
===================

Seven external-pointer widgets, each editing a ``var private`` global:

* ``edit_slider_float(safe_addr(g_volume), (id = "VOL_SLIDER", text =
  "Volume", v_min, v_max))`` — driven by a horizontal drag.
* ``edit_input_int(safe_addr(g_count), (id = "COUNT_INPUT", text =
  "Count", step = 1))`` — driven by ``imgui_focus`` + ``imgui_key_type``.
* ``edit_checkbox(safe_addr(g_enabled), (id = "ENABLED_CHECK", text =
  "Enabled"))`` — driven by a click.
* ``edit_drag_float3(safe_addr(g_pos), (id = "POS_DRAG", ...))`` —
  driven by ``imgui_force_set`` with a ``float3`` value.
* ``edit_color_edit3(safe_addr(g_accent), (id = "ACCENT_COLOR", ...))``
  — driven by ``imgui_force_set`` with a ``float3`` value (RGB).
* ``edit_combo(safe_addr(g_quality_idx), (id = "QUALITY_COMBO",
  items <- g_qualities))`` — driven by ``imgui_force_set`` with an ``int``
  index.
* ``edit_slider_angle(safe_addr(g_angle), (id = "ANGLE_SLIDER", ...))``
  — driven by ``imgui_force_set`` with a radian value (UI displays degrees).

Each widget's read-only sibling under the ``// Readout`` separator
shows the underlying ``var private`` value updating live with each
edit.

safe_addr vs unsafe(addr)
=========================

``safe_addr(local_or_global)`` is the right form for plain locals and
globals. ImGui needs a stable pointer to ``T``; ``safe_addr`` enforces
that.

It rejects struct-field-via-reference lvalues at compile time -- there
the field's lifetime is the reference's, which the compiler can't
guarantee outlives the widget call. For those, fall back to
``unsafe(addr(struct.field))`` and accept the responsibility for
lifetime.

The ``id = "..."`` literal is REQUIRED on every ``edit_*`` call. It's
the path leaf in widget telemetry; missing it is a compile-time error
from ``EditExternalCallMacro``. No implicit ``:line:col`` fallback,
because the edit_* family doesn't auto-emit a state struct that could
carry the path.

Driving the tour
================

Standalone (windowed):

.. code-block:: bash

   daslang modules/dasImgui/examples/tutorial/editing_external.das

Live (with reload):

.. code-block:: bash

   daslang-live modules/dasImgui/examples/tutorial/editing_external.das

Drive the widgets from outside via ``imgui_force_set`` / ``imgui_focus`` /
``imgui_key_type`` / ``imgui_mouse_play`` -- the recorded APNG above
exercises every shape via
``tests/integration/record_editing_external.das``.

.. seealso::

   Full source: :download:`examples/tutorial/editing_external.das <../../../examples/tutorial/editing_external.das>`

   Recording driver: ``tests/integration/record_editing_external.das``.

   :ref:`State telemetry <tutorial_state_telemetry>` — the snapshot
   path that ``edit_*`` widgets register under.

   :ref:`Driving outside <tutorial_driving_outside>` — the
   ``imgui_force_set`` / ``imgui_mouse_play`` / ``imgui_key_type`` verbs
   used by the recording driver above.

   :ref:`Recording <tutorial_recording>` — the two-shell driver setup.
