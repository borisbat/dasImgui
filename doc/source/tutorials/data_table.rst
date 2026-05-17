.. _tutorial_data_table:

#######################
data_table
#######################

ImGui's tables API — ``BeginTable`` / ``EndTable`` with body-internal
``TableSetupColumn`` / ``TableHeadersRow`` / ``TableNextRow`` /
``TableSetColumnIndex`` / ``TableNextColumn`` cursor primitives — lives
behind one boost container plus six snake_case pass-throughs in
``imgui/imgui_table_builtin``. The container is named ``data_table`` (not
``table``) because ``table`` is a daslang reserved keyword for the
``table<K;V>`` type constructor.

The container takes the ImGui id, the column count, the flags, an outer
size and an inner width — same five arguments the cpp ``BeginTable`` takes —
and brackets the matching ``EndTable``. Inside the body, the row/column
cursor calls are plain pass-throughs that resolve in the
``imgui_table_builtin`` module namespace (so the project-wide lint, which
forbids raw ``imgui::*`` calls in user code, stays satisfied without an
allow-list extension).

Source: ``examples/tutorial/data_table.das``.

************
Walkthrough
************

.. image:: ../_static/tutorials/data_table.apng
   :alt: data_table recording

.. literalinclude:: ../../../examples/tutorial/data_table.das
   :language: das
   :linenos:

Requires
========

One extra module on top of the baseline boost layer:

* ``imgui/imgui_table_builtin`` — the ``data_table`` container plus the
  six ``table_*`` snake_case primitives the body calls into.

Container shape
===============

``data_table`` follows the same named-tuple convention as the other
containers (``window`` / ``child`` / ``tab_bar``):

.. code-block:: das

   data_table(MY_TABLE, (text = "##rows", columns = 3,
                          flags = ImGuiTableFlags.Borders,
                          outer_size = float2(0.0f, 0.0f),
                          inner_width = 0.0f)) {
       // body
   }

``text`` is the ImGui id (use the ``##suffix`` convention to keep it
out of the visible label). ``columns`` is the column count;
``outer_size = float2(0,0)`` lets ImGui auto-size; ``inner_width = 0.0f``
means "no explicit inner width" (use the outer width).

Body primitives
===============

The six body cursor calls are plain ``def public`` wrappers — same
arguments as the underlying ImGui calls, snake_case names:

* ``table_setup_column(label, flags?, init_width?, user_id?)`` — declare a
  column before the header row.
* ``table_setup_scroll_freeze(cols, rows)`` — pin the first N columns / M
  rows during scrolling.
* ``table_headers_row()`` — submit the header row using the
  ``table_setup_column`` labels.
* ``table_next_row(flags?, min_row_height?)`` — start the next row.
* ``table_set_column_index(col) -> bool`` — jump to a specific column;
  returns ``true`` when the column is visible.
* ``table_next_column() -> bool`` — advance one column (or wrap to next
  row); also returns the visibility bool.

``TableState`` (the container's state struct) echoes per-call config —
columns, flags, outer_size, inner_width — so snapshot consumers can read
the table's shape without parsing the daslang call site. Sort-spec capture
and multi-select hand-off are deliberately deferred to the upcoming
``tables.das`` port and extend the state additively.

Why the name
============

``table`` is a daslang reserved keyword — the type constructor for
``table<K;V>`` (the hash-map type). Defining a function or container named
``table`` is a parse error. ``data_table`` follows the standard UI-library
term (Material's ``DataTable``, Bootstrap's ``table``, etc.) and disambiguates
from the type namespace at every call site.

Standalone vs live
==================

Same convention as previous tutorials. ``daslang.exe`` runs the table
once and exits at ``exit_requested()``. ``daslang-live`` keeps the window
open and reloads on source edits.

.. seealso::

   Full source: :download:`examples/tutorial/data_table.das <../../../examples/tutorial/data_table.das>`

   Integration test: ``tests/integration/test_app_small_property_editor.das``
   (uses the same ``data_table`` container surface).

   :ref:`Boost macros <stdlib_imgui_boost_section>` — the macro layer.
