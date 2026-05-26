.. _tutorial_narrative_widgets:

#######################
Narrative widgets
#######################

The narrative family is dasImgui's set of read-only display widgets — text
emission with optional color, emphasis, bullets, or label/value framing.
All share a ``NarrativeState`` (or ``LabelTextState``) payload that echoes
the call-site string back into the snapshot, so playwright tests can
assert "the label says what I expect" without any layout state.

The nine rails:

* ``text("...")`` — one line of plain text. Implemented via
  ``TextUnformatted`` (no printf-style format expansion).
* ``text_unformatted("...")`` — explicit alias for ``text``; identical
  implementation. Exists so call sites can signal intent.
* ``text_wrapped("...")`` — reflows long strings to the window's content
  edge.
* ``text_colored((color = float4(...), text = ...))`` — colored variant.
* ``text_disabled("...")`` — greyed for non-actionable hints.
* ``bullet(IDENT)`` — bullet glyph alone (the only narrative widget that
  takes an ident).
* ``bullet_text("...")`` — bullet glyph + text bundled.
* ``label_text((key = ..., value = ...))`` — two-string display, both
  echoed into the payload.
* ``separator_text("...")`` — horizontal rule with a centered label.

Source: ``examples/tutorial/narrative_widgets.das``.

************
Walkthrough
************

.. raw:: html

   <video autoplay loop muted playsinline width="100%">
     <source src="../_static/tutorials/narrative_widgets.mp4" type="video/mp4">
     Your browser doesn't support HTML5 video. <a href="../_static/tutorials/narrative_widgets.mp4">Download the recording</a>.
   </video>

.. literalinclude:: ../../../examples/tutorial/narrative_widgets.das
   :language: das
   :linenos:

Requires
========

Baseline boost layer (``imgui/imgui_boost_v2`` re-exports
``imgui/imgui_widgets_builtin``). No extra modules.

text vs text_unformatted vs text_wrapped
========================================

* ``text(s)`` — emits ``s`` through ImGui's ``TextUnformatted(s)``. No
  printf-style format expansion; the string is rendered verbatim.
* ``text_unformatted(s)`` — identical to ``text(s)`` (same
  ``TextUnformatted`` call). Exists as an explicit-intent alias for call
  sites where ``unformatted`` reads better, or where you want to
  underscore the no-printf-expansion contract for readers.
* ``text_wrapped(s)`` — emits through ``TextWrapped(s)`` so the text
  reflows at the window's content edge. The wrap position respects
  ``with_text_wrap_pos`` if you've pushed one.

The payload shape is identical for all three; the alias-pair
(``text`` / ``text_unformatted``) renders identically, while
``text_wrapped`` is the one that actually changes rendering behavior.

Colored vs disabled
===================

``text_colored((color, text))`` takes an inline ``float4`` and renders the
text in that color. Useful for status callouts, error indicators, or
section accents. The color is per-call — no scope push needed.

``text_disabled(s)`` renders in ImGui's ``StyleColor.TextDisabled`` — the
greyed tone used for inert menu items and hints. The most common use is
the ``(?)`` help marker glyph (see :ref:`tutorial_flat_tooltips`).

Bullets
=======

``bullet(IDENT)`` emits the marker glyph alone — useful when you want
custom content (a colored swatch, an icon) immediately after the bullet.
The ident is required because ``bullet`` is the one narrative widget that
gets its own snapshot entry (the others are anonymous).

``bullet_text("...")`` is the bundled form — glyph + text in one call,
no ident, no separate snapshot entry. Use this 95% of the time; reach
for ``bullet(IDENT)`` + ``same_line`` + custom-glyph only when you
genuinely need the manual layout.

label_text
==========

``label_text((key, value))`` is ImGui's two-column property-sheet format
— ``key`` renders in the left label gutter, ``value`` in the right
column. The visual order matches ``LabelText("Version", "v2.0-detour")``
from the C++ side ("Version" on the left, "v2.0-detour" on the right).
Both strings round-trip through the snapshot payload, so snapshot-driven
property tests get both halves for assertion.

separator_text
==============

``separator_text("Section name")`` is a horizontal rule with the label
centered above it. Use it to break a long window into named sections;
much easier to scan than ``separator()`` followed by ``text("Section
name")``.

Snapshot shape
==============

All narrative widgets register entries under ``NARRATIVE_WIN/IDENT`` (for
the ident-having ones) or stay anonymous (for the rest). Anonymous calls
still bump the parent container's payload, but they don't surface a
distinct path.

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
       | jq '.globals."NARRATIVE_WIN/BULLET_MARK".payload.value'

.. seealso::

   Full source: :download:`examples/tutorial/narrative_widgets.das <../../../examples/tutorial/narrative_widgets.das>`

   Integration tests: ``tests/integration/test_narrative_text.das``,
   ``tests/integration/test_narrative_bullet.das``,
   ``tests/integration/test_narrative_separator.das``.

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
