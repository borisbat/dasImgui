.. _tutorial_display_widgets:

#######################
Display widgets
#######################

dasImgui's read-only display family wraps ImGui's two main *output* widgets
into the v2 boost surface. ``progress_bar`` wraps ``ImGui::ProgressBar``
with a ``ProgressBarState`` payload carrying ``{fraction, size, overlay}``;
``image`` wraps ``ImGui::Image`` with the full ``uv0`` / ``uv1`` /
``tint_col`` / ``border_col`` quartet plus a ``uint64`` reinterpret of the
texture handle for snapshot readability.

.. code-block:: das

   progress_bar((fraction = 0.33f,
                 size = float2(-1.0f, 0.0f),
                 overlay = "33%"))

   image((texture = font_tex,
          size = float2(96.0f, 96.0f),
          uv0 = float2(0.0f, 0.0f),
          uv1 = float2(1.0f, 1.0f),
          tint_col = float4(1.0f, 1.0f, 1.0f, 1.0f),
          border_col = float4(0.0f, 0.0f, 0.0f, 0.0f)))

Both widgets are auto-instanced — no caller-side ident, no telemetry path of
their own. Only the parent ``window(DISPLAY_WIN, ...)`` registers a routable
entry; per-call payload state lives in the rail's state struct.

Source: ``examples/tutorial/display_widgets.das``.

************
Walkthrough
************

.. raw:: html

   <video autoplay loop muted playsinline width="100%">
     <source src="../_static/tutorials/display_widgets.mp4" type="video/mp4">
     Your browser doesn't support HTML5 video. <a href="../_static/tutorials/display_widgets.mp4">Download the recording</a>.
   </video>

.. literalinclude:: ../../../examples/tutorial/display_widgets.das
   :language: das
   :linenos:

Requires
========

Baseline boost layer (``imgui/imgui_boost_v2`` re-exports the rail family
from ``imgui/imgui_widgets_builtin``). No extra modules.

progress_bar
============

``ProgressBarState`` mirrors the call-site values verbatim. ``fraction``
holds the **raw** call-site value (no clamp at the state level); ImGui
clamps to ``[0, 1]`` for the rendered bar, but the snapshot payload
reflects whatever the caller passed — so out-of-range inputs surface in
the snapshot for assertion. Pass a negative value for indeterminate
animation. ``size`` is the ImGui ``ImVec2``: ``-1.0f`` for the X
component fills available width; explicit pixels for fixed width.
``overlay`` is the centered label drawn on top of the bar — leave empty
for the auto-formatted percentage.

image
=====

``ImageState`` exposes ``user_texture_id`` as a ``uint64`` so the snapshot
can carry the texture handle as a readable number (raw ``void?`` would
serialize as a pointer string). All four ``uv0`` / ``uv1`` /
``tint_col`` / ``border_col`` defaults match the C++ ``ImGui::Image``
defaults so an unset call is the identity render. The tutorial uses the
ImGui font atlas (``GetIO().Fonts.TexID``) as a guaranteed-available
texture; production code passes a ``user_texture_id`` from your renderer
that targets a real GPU resource.

Snapshot shape
==============

The inner widgets don't register their own entries, but ``DISPLAY_WIN``'s
container snapshot still carries the rail's payload via its serializer
lambda. Probe with:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
       | jq '.globals."DISPLAY_WIN".payload'

The container payload aggregates each rail's per-call state (one entry per
call) in the order they fired this frame — useful for snapshot-driven
regression tests when you want to assert the second progress_bar's
fraction matches the sine-driven value.

.. seealso::

   Full source: :download:`examples/tutorial/display_widgets.das <../../../examples/tutorial/display_widgets.das>`

   Integration test: ``tests/integration/test_display_progress.das`` and ``tests/integration/test_display_image.das``.

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
