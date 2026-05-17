.. _tutorial_imgui_demo_app_main_menu:

#################################
imgui_demo: Main menu bar
#################################

The daslang port of ``ShowExampleAppMainMenuBar()`` (``imgui_demo.cpp:7009-7113``)
exercises the boost-v2 menu-container family + a narrow draw-list carve-out.
Source: ``examples/imgui_demo/app_main_menu.das`` (the scene module), driven
by ``examples/imgui_demo/harness_app_main_menu.das`` (the standalone harness).

.. image:: ../_static/tutorials/imgui_demo_app_main_menu.apng
   :alt: imgui_demo app_main_menu recording

What the port shows
===================

* ``main_menu_bar(MAIN_BAR_DEMO) { ... }`` hosts the viewport-attached menu
  strip — the same chrome ImGui draws above the main viewport.

* Two top-level cascades:

  * ``menu(APP_MENU_FILE, (text = "File", enabled = true)) { ... }`` —
    File menu with Open Recent / More.. / Options / Colors / Disabled /
    Checked / Quit. Nested ``menu()`` containers cascade.

  * ``menu(APP_MENU_EDIT, (text = "Edit", enabled = true)) { ... }`` —
    Edit menu with Undo / Redo / Cut / Copy / Paste.

* ``menu_item`` vs ``menu_label``: ``menu_item(EDIT_UNDO, ...)`` is a
  toggleable item (click flips ``state.value``); ``menu_label(EDIT_REDO,
  (..., enabled = false))`` is a non-toggling static row used here for
  visually-disabled Redo and the permanent-check "Checked" row.

* Per-color swatch in the Colors submenu:

  .. code-block:: das

     menu(FILE_COLORS, (text = "Colors", enabled = true)) {
         let sz = GetTextLineHeight()
         for (col in type<ImGuiCol>) {
             if (col == ImGuiCol.COUNT) continue
             let name = GetStyleColorName(col)
             let p = GetCursorScreenPos()
             *GetWindowDrawList() |> AddRectFilled(p, float2(p.x + sz, p.y + sz),
                                                   GetColorU32(col))
             dummy(FILE_COLORS_DUMMY[int(col)], (size = float2(sz, sz)))
             same_line(FILE_COLORS_SAMELINE[int(col)])
             menu_item(FILE_COLORS_ITEM[int(col)], (text = name))
         }
     }

  ``GetStyleColorName`` / ``GetWindowDrawList`` / ``AddRectFilled`` are the
  three raw ``imgui::`` calls added to ``ALLOWED_IMGUI`` to make the swatch
  paint legal under default-on lint.

Driving the demo
================

Standalone (windowed):

.. code-block:: bash

   daslang modules/dasImgui/examples/imgui_demo/harness_app_main_menu.das

Live (with reload):

.. code-block:: bash

   daslang-live modules/dasImgui/examples/imgui_demo/harness_app_main_menu.das

Headless (CI):

.. code-block:: bash

   daslang modules/dasImgui/examples/imgui_demo/harness_app_main_menu.das -- \
       --headless --headless-frames=60

Menu-bar widget telemetry caveat
================================

``main_menu_bar()`` and its child ``menu()`` containers register under the
expected paths (``MAIN_BAR_DEMO`` / ``MAIN_BAR_DEMO/APP_MENU_FILE`` / ...)
but their ``bbox`` field in the snapshot is ``(0, 0, 0, 0)``. Reason:
``stateless_finalize`` reads ``GetItemRectMin/Max()`` which is degenerate
for menu-bar chrome at finalize time.

Practical impact: ``widget_center(snap, "MAIN_BAR_DEMO/APP_MENU_FILE")``
returns ``(0, 0)`` and synthetic clicks miss the top-left corner. Recording
drivers hardcode pixel coords for menu headers — see
``tests/integration/record_imgui_demo_app_main_menu.das`` and
``skills/recording.md``.

.. seealso::

   Scene module: :download:`examples/imgui_demo/app_main_menu.das <../../../examples/imgui_demo/app_main_menu.das>`

   Single-scene harness: :download:`examples/imgui_demo/harness_app_main_menu.das <../../../examples/imgui_demo/harness_app_main_menu.das>`

   Recording driver: ``tests/integration/record_imgui_demo_app_main_menu.das``.

   Integration smoke: ``tests/integration/test_imgui_demo_app_main_menu.das``.
