.. _tutorial_drawlist:

#######################
Drawlist rail
#######################

ImGui exposes three viewport-level draw lists — window, foreground, background —
plus a family of low-level ``Add*`` primitives that paint directly to them
(``AddLine``, ``AddRect``, ``AddCircle``, etc.). The boost layer wraps them
behind three scope wrappers and eight primitive functions:

.. code-block:: das

   with_window_drawlist() $(var dl) {
       dl |> add_rect_filled(p0, p1, rgba(40u, 80u, 200u, 200u))
       dl |> add_line(a, b, rgba(255u, 255u, 0u, 255u), 2.0f)
   }

Every primitive registers a per-frame snapshot entry under a synthesized
``<window>/<mod>:<line>:<col>`` path key, so playwright / mouse-cards can
target a specific call site by path without the caller declaring a state
global. Drawlist primitives are decoration-only — no hover / active / focus
state is captured.

Source: ``examples/tutorial/drawlist.das``.

************
Walkthrough
************

.. image:: ../_static/tutorials/drawlist.apng
   :alt: drawlist rail recording

.. literalinclude:: ../../../examples/tutorial/drawlist.das
   :language: das
   :linenos:

Scope wrappers
==============

Three thin wrappers cover the three drawlist scopes:

* ``with_window_drawlist() $(var dl) { ... }`` — current window's drawlist.
  Painting is clipped to the window's content region and stacks under any
  subsequent widgets rendered in this window.
* ``with_foreground_drawlist() $(var dl) { ... }`` — top-most foreground
  drawlist. Paints over every window on the viewport. Use for HUD overlays,
  drag indicators, tooltips that must escape window clipping.
* ``with_background_drawlist() $(var dl) { ... }`` — bottom-most background
  drawlist. Paints under every window on the viewport. Use for full-viewport
  backdrops (gradients, vignettes, debug grids).

Each wrapper acquires the drawlist pointer, yields it to the block as ``dl``,
and exits. There's no push / pop pairing under the hood — drawlists are
viewport-level state that any ImGui code can reach via ``GetWindowDrawList``
/ ``GetForegroundDrawList`` / ``GetBackgroundDrawList``; the wrappers exist
to give the rail a uniform body shape (``with_X() $(var dl) { dl |> add_*(...) }``)
and to keep raw ``GetWindowDrawList`` calls off the boost surface.

Primitives
==========

Eight ``[drawlist_prim]``-tagged painters cover the geometric basics:

* ``add_line(dl, a, b, col, thickness = 1.0f)``
* ``add_rect(dl, a, b, col, rounding = 0.0f, flags = ImDrawFlags.None, thickness = 1.0f)``
* ``add_rect_filled(dl, a, b, col, rounding = 0.0f, flags = ImDrawFlags.None)``
* ``add_circle(dl, center, radius, col, num_segments = 0, thickness = 1.0f)``
* ``add_circle_filled(dl, center, radius, col, num_segments = 0)``
* ``add_triangle(dl, a, b, c, col, thickness = 1.0f)``
* ``add_triangle_filled(dl, a, b, c, col)``
* ``add_text(dl, pos, col, text)``

``col`` is a packed ABGR ``uint`` — use ``rgba(r, g, b, a)`` to build one,
or ``GetColorU32(ImGuiCol.*)`` for style-colour references. Positions are
screen-space pixels; widget-relative drawing typically anchors on
``GetCursorScreenPos`` / ``GetItemRectMin`` / ``GetItemRectMax``.

Path-key telemetry
==================

The ``[drawlist_prim]`` annotation synthesizes a stable
``<mod>:<line>:<col>`` path key at every call site (no per-call state
global is registered). Each primitive's body publishes a lightweight
``WidgetEntry`` — ``kind`` (``"add_line"`` / ``"add_rect"`` / ...) plus
``bbox`` — into the per-frame registry under that key. Playwright /
mouse-cards can then target a specific call site by path:

.. code-block:: das

   var snap = wait_for_widget(d, "MY_WIN/<mod>:42:8", 15.0f)
   t |> equal(find_widget(snap, "MY_WIN/<mod>:42:8")?["kind"] ?? "", "add_rect", ...)

Because the synthesized key shifts on edits, tests typically enumerate
drawlist entries by ``kind`` (``"add_rect"`` etc.) rather than hardcoding
the line / column — see ``tests/integration/test_drawlist_path_key.das`` for
the walker pattern.

Standalone vs live
==================

Same convention as the other tutorials. ``daslang.exe`` runs the demo
headlessly to frame N; ``daslang-live`` keeps the window open and reloads
on source edits.

.. seealso::

   Full source: :download:`examples/tutorial/drawlist.das <../../../examples/tutorial/drawlist.das>`

   Integration tests: ``tests/integration/test_drawlist_primitives.das``,
   ``tests/integration/test_with_window_drawlist.das``,
   ``tests/integration/test_drawlist_path_key.das``.

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
