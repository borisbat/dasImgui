.. _tutorial_imgui_demo_about:

##########################
imgui_demo: About window
##########################

The daslang port of Dear ImGui's ``ShowAboutWindow`` (``imgui_demo.cpp:6460-6622``)
is the smallest end-to-end demo that exercises the boost-v2 surface plus the
imperative-clipboard-commands family. Source:
``examples/imgui_demo/about.das`` (the scene module), driven by
``examples/imgui_demo/harness_about.das`` (the standalone harness).

.. image:: ../_static/tutorials/imgui_demo_about.apng
   :alt: imgui_demo about recording

What the port shows
===================

* ``window(ABOUT_WINDOW, ...)`` hosts the title, version line, license
  blurb, and funding ask -- the static text body of the C++ original
  ported to ``text(...)``.

* ``edit_checkbox(safe_addr(ABOUT_SHOW_CONFIG_INFO), ...)`` gates the
  Config/Build dump; flipping it expands the inner ``child(ABOUT_CFG_INFOS_CHILD, ...)``
  with the io / style field readout.

* ``button(BUTTON_COPY, (text = "Copy to clipboard"))`` -- the v2 click-state
  form returning ``bool``, replacing the legacy ``Button("...")`` raw call.

* The clipboard tee is built from three imperative passthroughs in
  ``imgui_widgets_builtin.das``:

  .. code-block:: das

     if (copy_to_clipboard) {
         log_to_clipboard()
         log_text("```\n")              // markdown fence
     }
     // text() lines render AND tee
     if (copy_to_clipboard) {
         log_text("\n```\n")
         log_finish()
     }

  ``log_text`` is the small wrapper added alongside the existing
  ``log_to_clipboard`` / ``log_finish`` pair so the scene runs clean under
  default-on ``imgui_lint``.

Driving the demo
================

Standalone (windowed):

.. code-block:: bash

   daslang.exe modules/dasImgui/examples/imgui_demo/harness_about.das

Live (with reload):

.. code-block:: bash

   daslang-live modules/dasImgui/examples/imgui_demo/harness_about.das

Headless (CI):

.. code-block:: bash

   daslang.exe modules/dasImgui/examples/imgui_demo/harness_about.das -- \
       --headless --headless-frames=60

.. seealso::

   Scene module: :download:`examples/imgui_demo/about.das <../../../examples/imgui_demo/about.das>`

   Single-scene harness: :download:`examples/imgui_demo/harness_about.das <../../../examples/imgui_demo/harness_about.das>`

   Recording driver: ``tests/integration/record_imgui_demo_about.das``.

   Integration smoke: ``tests/integration/test_imgui_demo_about.das``.
