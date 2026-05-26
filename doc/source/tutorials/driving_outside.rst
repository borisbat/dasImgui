.. _tutorial_driving_outside:

#######################
Driving from outside
#######################

Every boost widget that previous tutorials wrote registers a path in
the telemetry tree (``DRIVE_WIN/USER``, ``DRIVE_WIN/SPEED``,
``DRIVE_WIN/RUN_BTN`` ...). That path is **also** an HTTP endpoint:
the boost layer ships ``[live_command]`` handlers (``imgui_snapshot``,
``imgui_set``, ``imgui_click``, ``imgui_open``, ``imgui_close``,
``imgui_focus``) that look up the target in the registry and queue the
matching pending field on the widget's state struct. Next frame, the
render function consumes the pending field and ImGui sees the effect
as if a real input device drove it.

This tutorial flips the point of view: instead of writing the daslang
side, write the **driver** — a curl / Python / Bash script that issues
JSON commands at a running daslang-live app. Every interaction the
user could perform via mouse/keyboard has a curl equivalent, and the
two surfaces use one in-memory model.

Source: ``examples/tutorial/driving_outside.das`` — a small target app
exposing five widget kinds. The recording is **driven entirely by
JSON commands** — no synthesized mouse moves into widget centers.

************
Walkthrough
************

.. raw:: html

   <video autoplay loop muted playsinline width="100%">
     <source src="../_static/tutorials/driving_outside.mp4" type="video/mp4">
   </video>

.. literalinclude:: ../../../examples/tutorial/driving_outside.das
   :language: das
   :linenos:

The command surface
===================

Three dispatch levels, in order of decreasing abstraction:

* **L1 — synth IO**: ``imgui_mouse_pos``, ``imgui_mouse_button``,
  ``imgui_mouse_play``, ``imgui_key_press``, ``imgui_key_type``. The
  driver pretends to be a mouse or keyboard, feeding events into the
  ImGui input queue. Used by ``imgui_playwright`` for cursor-visible
  recordings.
* **L2 — semantic actions on registered widgets**: ``imgui_click``,
  ``imgui_focus``. The framework looks up the widget by path and
  queues ``state.pending_click = true`` (or the equivalent). Whatever
  the widget's render function would do on a real click happens next
  frame. No bbox lookup, no cursor motion.
* **L3 — value writes**: ``imgui_set``. Same lookup, queues
  ``state.has_pending = true`` + ``state.pending_value = ...``. The
  render function consumes the pending value and submits it to ImGui
  on the next frame.

Plus the read side and the container channel:

* ``imgui_snapshot`` — full registry as JSON, the first call in any
  driver.
* ``imgui_open`` / ``imgui_close`` — set ``state.pending_open`` /
  ``state.pending_close`` on container widgets (popups, closable
  windows, tabs, tree nodes).

Always L2/L3 first — they're race-free under the framework's
per-frame consumption rule. Drop to L1 only when there's no L2
counterpart (drag along a custom trajectory, paste a long string into
a focused input, sustain a chord, ...).

imgui_snapshot — read the world
===============================

The first call every driver makes:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command

Response shape:

.. code-block:: text

   {
     "frame": 412,
     "globals": {
       "DRIVE_WIN": {
         "kind": "window",
         "bbox": [30, 30, 670, 490],
         "hex_id": "0x2c1a8f4b",
         "payload": { "open": true, "size": [640, 460], ... }
       },
       "DRIVE_WIN/SPEED": {
         "kind": "slider_int",
         "bbox": [...],
         "hex_id": "0x...",
         "payload": { "value": 5, "bounds": [0, 10], ... }
       },
       "DRIVE_WIN/RUN_BTN": {
         "kind": "button",
         "bbox": [...],
         "payload": { "click_count": 0 }
       },
       ...
     },
     "io": {
       "mouse_pos": [320, 180],
       "active_widget": "..."
     }
   }

Use it to:

* discover what's on screen and what kind each widget is;
* read ``bbox`` for L1 mouse synthesis (when needed);
* check ``payload`` for current state (test assertions);
* read ``hex_id`` for fallback dispatch when the path isn't stable.

imgui_set — value writes
========================

``imgui_set`` is the universal value-write endpoint — slider, checkbox,
combo, color, text input, dock-window position. Type-dispatched on the
value's JSON shape:

.. code-block:: bash

   # string into a text input
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/USER","value":"Alice"}}' \
        localhost:9090/command

   # int into a slider
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/SPEED","value":7}}' \
        localhost:9090/command

   # int into a combo (selected index)
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/PRESET","value":2}}' \
        localhost:9090/command

   # array-of-floats into a color picker
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/TINT","value":[0.2,0.7,0.4]}}' \
        localhost:9090/command

Under the hood: the registered dispatcher for the widget's state struct
unpacks the JSON, type-checks it against the state's value field,
flips ``has_pending = true``, stores ``pending_value``. The render
function picks it up next frame; ImGui submits the new value through
its own ``UpdateValue`` path.

imgui_click — fire a click
==========================

``imgui_click`` doesn't synthesize a mouse event — it sets
``state.pending_click = true`` on the registered ``ClickState`` (or its
equivalent on selectable / menu_item):

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_click","args":{"target":"DRIVE_WIN/RUN_BTN"}}' \
        localhost:9090/command

The button's render function returns ``true`` next frame just like a
real click would, the ``click_count`` increments, the daslang side
sees both the inline ``if (button(...))`` and ``RUN_BTN.clicked /
RUN_BTN.click_count`` as expected. No mouse position has to land on
the button.

imgui_open / imgui_close — containers
=====================================

Containers expose an open-state channel through ``state.pending_open``
and ``state.pending_close``. ``imgui_open`` flips ``pending_open``;
``imgui_close`` flips ``pending_close``. The next frame's render
function applies the change:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_open","args":{"target":"DRIVE_WIN/STATUS_POPUP"}}' \
        localhost:9090/command
   curl -X POST -d '{"name":"imgui_close","args":{"target":"DRIVE_WIN/STATUS_POPUP"}}' \
        localhost:9090/command

The same channel handles popups, closable windows, tabs (closable-tab
visibility specifically — see ``tutorial_containers`` for the tab-item
caveat), tree nodes, and collapsing headers.

The flow on a single command
============================

Every command runs the same path:

1. ``daslang-live`` HTTP server receives ``POST /command``.
2. Routes by ``name`` to the registered ``[live_command]`` handler.
3. Handler looks up ``target`` in the registry's path map (or hex_id
   reverse map).
4. Mutates the matching state struct's pending field; returns
   ``{"ok": true, ...}`` on the HTTP response.
5. **Next frame** the script's ``update()`` runs; the widget's render
   function sees the pending flag, applies it, ImGui responds, the
   updated state is observable from the next ``imgui_snapshot``.

So **commands are one-frame-delayed by design** — there's no
ambiguity about which frame's state corresponds to a given response.
For test harnesses that need to read the result, the canonical pattern
is: command, then ``await_quiescent`` (waits a frame), then
``imgui_snapshot``.

Standalone vs live
==================

The HTTP server only exists under ``daslang-live``. Standalone
``daslang.exe`` runs the same script but the live-command endpoints
aren't bound — drive-from-outside scenarios require the live host.

Driving from outside (recap)
============================

A complete drive sequence for this tutorial's app:

.. code-block:: bash

   # Read the world
   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command

   # Write each widget kind
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/USER","value":"Alice"}}' \
        localhost:9090/command
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/SPEED","value":7}}' \
        localhost:9090/command
   curl -X POST -d '{"name":"imgui_set","args":{"target":"DRIVE_WIN/PRESET","value":2}}' \
        localhost:9090/command
   curl -X POST -d '{"name":"imgui_click","args":{"target":"DRIVE_WIN/RUN_BTN"}}' \
        localhost:9090/command
   curl -X POST -d '{"name":"imgui_open","args":{"target":"DRIVE_WIN/STATUS_POPUP"}}' \
        localhost:9090/command

The recording at the top of this page runs this exact sequence — no
mouse moves, just JSON commands. Every effect you see in the APNG is
the result of an ``imgui_set`` / ``imgui_click`` / ``imgui_open``
flowing through the state-struct pending channel.

Next steps
==========

Now that the JSON-driven view is explicit, the **visual aids tour**
walks through every overlay the recordings used: highlight, mouse
trail, cursor sprite, narrate, key HUD, focus rect — all
``[live_command]``-wrapped so the same curl pattern reaches them.

.. seealso::

   Full source: :download:`examples/tutorial/driving_outside.das <../../../examples/tutorial/driving_outside.das>`

   Richer reference: ``examples/features/io_synth_text.das`` —
   ``imgui_key_type`` chains a coroutine that pushes one ``AddInputCharactersUTF8``
   per frame; the L1 keyboard layer in action.

   Snapshot contract: ``imgui_boost_runtime.das``'s
   ``g_serializers`` per-kind payload definitions.

   Previous tutorial: :ref:`tutorial_live_reload`

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
