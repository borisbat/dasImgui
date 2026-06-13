.. _tutorial_file_dialog:

#######################
file_dialog
#######################

A native, reusable **New / Open / Save** file dialog, built entirely from the
boost DSL and living in ``imgui/imgui_file_dialog``. Because it is composed from
boost widgets (``popup_modal`` / ``data_table`` / ``selectable_label`` /
``input_text`` / ``combo`` / ``button``) rather than a bound C++ file-dialog
library, **every element registers on the snapshot registry** — the whole dialog
is :ref:`imgui_playwright <tutorial_driving_outside>`-drivable (a bound C++
dialog renders raw ImGui and would be invisible to it).

It mirrors the core UX of a desktop file picker: a clickable directory
breadcrumb plus ``..``, a sortable Name / Size / Type table, an extension-filter
dropdown, multi-select in open mode, a filename field in save / create mode, and
an overwrite-confirm step.

Source: ``examples/tutorial/file_dialog.das``.

************
Walkthrough
************

The dialog is **immediate-mode** — there are no stored callbacks (daslang blocks
can't be stored across frames). The flow is three calls:

1. a trigger (button / menu item) calls ``file_dialog_open(cfg)`` with a mode,
   a start directory and a list of extension filters;
2. ``file_dialog_draw()`` is called **every frame**, at the top level of
   ``update()`` (outside any window, so the registry path stays a clean
   ``FILEDLG/...``). It renders the modal when open and returns this frame's
   ``FileDialogResult``;
3. on ``confirmed``, the chosen path(s) are read with
   ``file_dialog_selection()`` / ``file_dialog_selected_path()``.

.. literalinclude:: ../../../examples/tutorial/file_dialog.das
   :language: das
   :linenos:

Requires
========

One module on top of the harness:

* ``imgui/imgui_file_dialog`` — the dialog component. It pulls in
  ``imgui_table_builtin`` (the sortable ``data_table``),
  ``imgui_widgets_builtin`` and ``imgui_containers_builtin`` (the leaf widgets +
  ``popup_modal``), and ``daslib/fio`` (directory listing) transitively.

Public API
==========

.. code-block:: das

   enum FileDialogResult { none; confirmed; cancelled }
   enum FileDialogMode   { open; save; create }   // 'new' is a reserved keyword

   struct FileDialogFilter { caption : string; ext : string }  // ext without the dot; "" = all
   struct FileDialogConfig {
       title : string = "Select File"
       start_dir : string = ""                   // "" => current working directory
       filters : array<FileDialogFilter>         // empty => all files
       mode : FileDialogMode = FileDialogMode.open
       max_selection : int = 1                   // open mode; 0 = unlimited
   }

   def public file_dialog_open(cfg : FileDialogConfig) : void
   def public file_dialog_draw() : FileDialogResult
   def public file_dialog_selection() : array<string>   // confirmed absolute path(s)
   def public file_dialog_selected_path() : string      // first selection (convenience)
   def public file_dialog_current_dir() : string
   def public file_dialog_is_open() : bool

The result is polled, not pushed: ``file_dialog_draw()`` returns ``confirmed``
exactly on the frame the user commits, ``cancelled`` on the frame they close /
press *Escape*, and ``none`` otherwise. The accessors stay valid from the
``confirmed`` frame until the dialog is reopened.

Modes
=====

* **open** — pick one or more existing files. Selection follows the usual
  modifiers: plain click selects, **Ctrl+click** toggles, **Shift+click** selects
  a range, clamped to ``max_selection`` (``0`` = unlimited). Double-clicking a
  file confirms it; double-clicking a directory enters it.
* **save** / **create** — type a name in the filename field (clicking a row fills
  it). The active filter's extension is appended if missing. If the name already
  exists, an **overwrite-confirm** sub-modal (``FILEDLG/OVERWRITE``) gates the
  commit. (``create`` is the "New" flavor — same name-entry path; ``new`` itself
  is a reserved keyword, hence the enum name.)

Navigation and sorting
=======================

The current directory is listed with ``daslib/fio``'s ``dir`` + per-entry
``stat`` (so directories are always shown for navigation, files are filtered by
the active extension). A clickable breadcrumb of ancestor directories plus a
``..`` button drive ``navigate_to``; directories always sort first.

The file list is a :ref:`data_table <tutorial_data_table>` with the
``Sortable`` flag and three ``table_setup_column`` calls tagged with stable
``user_id`` values (``COL_NAME`` / ``COL_SIZE`` / ``COL_TYPE``). A
``sort_specs()`` block captures the active sort key and re-orders the view
(directories first, then the chosen column). Each row's first cell is a
``selectable_label`` with ``SpanAllColumns | AllowDoubleClick`` so a click
anywhere on the row selects it and a double-click enters / confirms.

Drivability
===========

Every interactive element is a registry-backed boost widget, so a driver can
operate the dialog by id:

.. list-table::
   :header-rows: 1

   * - Element
     - Path
     - Verb
   * - Modal
     - ``FILEDLG``
     - snapshot / ``imgui_open``
   * - Parent / breadcrumb
     - ``FILEDLG/UP`` · ``FILEDLG/CRUMB[i]``
     - ``imgui_click``
   * - Filter dropdown
     - ``FILEDLG/FILTER_COMBO``
     - ``imgui_force_set {"value": N}``
   * - File table
     - ``FILEDLG/FILE_TABLE``
     - sort via header click
   * - File row *i*
     - ``FILEDLG/FILE_TABLE/ROW[i]``
     - ``imgui_click`` (select) · ``double_click`` (enter dir / open file)
   * - Filename field
     - ``FILEDLG/NAME_FIELD``
     - ``imgui_force_set {"value": "name"}``
   * - OK / Cancel
     - ``FILEDLG/BTN_OK`` · ``FILEDLG/BTN_CANCEL``
     - ``imgui_click``
   * - Overwrite confirm
     - ``FILEDLG/OVERWRITE/OW_YES`` · ``.../OW_NO``
     - ``imgui_click``

Standalone vs live
==================

Same convention as the other tutorials. ``daslang.exe`` runs the demo once and
exits at ``exit_requested()``; ``daslang-live`` keeps the window open and reloads
on source edits.

.. seealso::

   Full source: :download:`examples/tutorial/file_dialog.das <../../../examples/tutorial/file_dialog.das>`

   Integration test: ``tests/integration/test_file_dialog.das`` — drives the
   dialog through ``imgui_playwright`` (open → cancel, save → type → confirm).

   :ref:`data_table <tutorial_data_table>` — the sortable table the file list is
   built on. :ref:`popup_modal <tutorial_popup_modal>` — the modal container.
