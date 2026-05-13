.. _tutorial_recording:

#######################
Recording APNGs
#######################

Every APNG in this tutorial set was produced the same way: a tiny
**subject** app hosted under ``daslang-live``, then a **driver** script
running in a second shell that toggled visual aids, called
``record_start``, narrated each interaction, performed the action, and
called ``record_stop``. This is the meta tutorial — the driver script
is the artifact, and the embedded recording demonstrates itself.

Source files:

* ``examples/tutorial/recording.das`` — the subject: a one-slider
  one-button window. Tiny on purpose so every frame in the APNG
  corresponds to one specific driver call.
* ``tests/integration/record_recording.das`` — the driver. Walked
  through below.

************
The subject
************

.. literalinclude:: ../../../examples/tutorial/recording.das
   :language: das
   :linenos:

The subject is a normal dasImgui live-reload app — same shape as every
other tutorial's subject. The recorder doesn't touch the subject at
all; it operates entirely through the live-command HTTP surface.

************
The driver
************

.. image:: ../_static/tutorials/recording.apng
   :alt: recording recording

.. literalinclude:: ../../../tests/integration/record_recording.das
   :language: das
   :linenos:

Anatomy of a driver
===================

1. **Connect to the live host.** ``ImguiApp`` bundles the base URL +
   transport into a value every playwright helper takes as its first
   argument. ``wait_until_ready`` polls until the HTTP server answers,
   so the driver can be launched concurrently with daslang-live and
   recover from the cold-start gap.

2. **Resolve widget centers.** ``wait_for_render`` polls
   ``imgui_snapshot`` until the named widget shows up in the registry
   (covers the first-frame gap where the subject's window exists but
   hasn't rendered yet). The helper ``widget_bbox`` / ``widget_center``
   extract the geometry from the snapshot JSON.

3. **Enable visual aids — BEFORE ``record_start``.**

   .. code-block:: das

      post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
      post_command(app, "imgui_cursor_sprite", JV((enabled = true)))

   ``imgui_mouse_trail`` draws a fading line behind the synthetic
   cursor. ``imgui_cursor_sprite`` draws a visible pointer at
   ``io.MousePos``. Without these, the recording shows widget state
   changing but no cursor — confusing for viewers.

4. **``record_start``.** Opens an APNG writer at ``file`` (relative to
   daslang-live's cwd, which is why every tutorial's shell-1 command
   ``cd``\\s into the asset directory first). ``fps`` controls the time
   stamps written into the APNG frame headers — not how often frames
   are captured. ``max_seconds`` caps the recording length.

   The writer pulls from a PBO ring on the GL side (4 buffers by
   default) — ``glReadPixels`` returns immediately, the actual readback
   happens 3 frames later, the encoder runs on a worker thread. Frames
   drop only if the worker can't keep up with the GL output rate, and
   even then dropping is graceful (the APNG just gets slightly choppier
   — never breaks).

5. **Narrate, then act — repeat.** The locked pacing rule:

   .. code-block:: text

      frames = 180   →  3.0 s of visible narrate
      sleep  = 3500u →  narrate disappears with ~500 ms gap
      sleep  = 1500u →  result-dwell after the action

   ``frames`` counts the APP's frame counter (60 fps under vsync), NOT
   the recorder's fps. So ``frames = 180`` is 3 seconds of real time,
   regardless of whether the recorder is at 30 fps or 60 fps.

6. **``record_stop``.** Flushes the APNG writer, joins the encoder
   thread, returns ``(saved, frames, duration_s, dropped, ok)`` so the
   driver can spot-check stats.

7. **Disable visual aids.** The host stays alive after the driver
   exits — clean up the cursor sprite + trail so the next driver (or
   a developer poking at the live host manually) starts from a clean
   slate.

The visual-aids stack
=====================

Four ``[live_command]`` toggles in ``imgui_visual_aids.das``:

* ``imgui_mouse_trail`` — fading line behind ``io.MousePos``. Args:
  ``enabled``, ``fade`` (seconds), ``color`` (RGBA uint).
* ``imgui_cursor_sprite`` — visible pointer drawn at ``io.MousePos``.
  Without it the cursor only exists in the OS layer, which screen
  recordings don't capture.
* ``imgui_narrate`` — a sticky-note callout with optional connector
  line to a target widget. Auto-fits to avoid sibling overlap;
  ``frames`` controls visibility duration.
* ``imgui_highlight`` — a colored rectangle around a widget's bbox for
  N frames. Useful for "look here" without text. ``imgui_auto_highlight``
  flips a global flag that fires highlight on every accepted live
  command — a one-shot debug aid.

Two more for keyboard work:

* ``imgui_key_hud`` — bottom-center keycap overlay + modifier strip.
  Pops a keycap for every synth key event; lights modifier pills
  while held. Useful for input-heavy demos.
* ``imgui_focus_rect`` — a rectangle around ``io.active_widget`` so
  the viewer can tell which widget keystrokes will land in.

The driver workflow in shell
============================

The two-shell pattern every tutorial uses:

.. code-block:: bash

   # shell 1 — host with cwd = the asset dir so the APNG lands there
   cd modules/dasImgui/doc/source/_static/tutorials
   ../../../../../../bin/Release/daslang-live.exe \
       ../../../../examples/tutorial/recording.das

   # shell 2 — fire the driver, exits when done
   bin/Release/daslang.exe modules/dasImgui/tests/integration/record_recording.das

The host stays alive after the driver exits; if the recording was bad,
re-run shell 2 — no need to restart daslang-live. The driver script
nukes the previous file (``rm -f <name>.apng``) at the top, or
``record_start`` returns ``{"error":"already recording"}`` if a prior
session leaked.

Stop conditions
===============

``record_stop`` is the clean exit. Three other ways the writer
finalizes:

* ``max_seconds`` expires — same APNG, frame count + duration match
  the cap.
* ``stbi_apng_frame`` returns an error (rare; usually disk full or
  permission denied) — writer auto-stops, returns the partial APNG.
* daslang-live shuts down — the ``[on_app_exit]`` hook on the
  recorder finalizes any in-flight ring before tearing down GL state.

In practice ``record_stop`` is the only exit you'll see; the others
are safety nets.

Replay stability
================

The same driver run against the same subject produces APNGs that look
the same to a viewer — but they're not byte-identical. ImGui's frame
times jitter, vsync alignment shifts, the PBO ring may stall once or
twice on encoder backpressure. ``dropped`` in the response is the
useful metric: anything under ``capture_pbo_count + a few`` is fine.
Higher means the encoder couldn't keep up — try lowering the subject's
render rate, simplifying the subject, or raising ``capture_pbo_count``.

Standalone vs live
==================

The whole recording surface — visual aids, ``record_start`` /
``record_stop``, the playwright helpers — runs only under
``daslang-live``. Standalone ``daslang.exe`` runs the subject, but
the HTTP-bound live commands aren't registered. The driver script
itself is a normal ``daslang.exe`` script — it just talks HTTP to a
host running on another process.

Driving from outside
====================

The same JSON commands the driver issues are reachable from curl:

.. code-block:: bash

   curl -X POST -d '{"name":"imgui_mouse_trail","args":{"enabled":true}}'      localhost:9090/command
   curl -X POST -d '{"name":"imgui_cursor_sprite","args":{"enabled":true}}'    localhost:9090/command
   curl -X POST -d '{"name":"record_start","args":{"file":"manual.apng","fps":30,"max_seconds":15}}' \
        localhost:9090/command

   # do whatever interactions interactively in the live window ...

   curl -X POST -d '{"name":"record_stop"}' localhost:9090/command

Use this for ad-hoc captures when the scripted driver would be
overkill — bug repros, "show me what this looks like" pings.

The end of the curriculum
=========================

The 12 tutorials in this set walk the dasImgui surface end-to-end:
basics, widgets, layout, docking, style, identity, state, containers,
live reload, the JSON-driven view, the visual aids tour, and this
recording recipe. Beyond the curriculum, every ``examples/features/``
demo is a richer reference for one specific surface — those are the
go-to once the tutorials are familiar.

.. seealso::

   Subject source: :download:`examples/tutorial/recording.das <../../../examples/tutorial/recording.das>`

   Driver source: :download:`tests/integration/record_recording.das <../../../tests/integration/record_recording.das>`

   Recorder implementation: ``modules/dasOpenGL/opengl/opengl_live.das``
   (``record_start`` / ``record_stop`` plus the PBO ring).

   Visual aids: ``modules/dasImgui/widgets/imgui_visual_aids.das``.

   Playwright helpers: ``modules/dasImgui/widgets/imgui_playwright.das``.

   Previous tutorial: :ref:`tutorial_driving_outside`

   Curriculum top: :ref:`tutorials_dasimgui`
