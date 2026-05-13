Block-form test harness for daslang-live + dasImgui apps. Spawns a host
process, configures a transport (HTTP by default), and runs a test block
against the live registry — click a widget by path, set a value, await
quiescence, snapshot the surface, expect a value or render state. The
``with_imgui_app(...) { ... }`` lifecycle handles launch / handshake /
shutdown so each test stays a single block; ``with_imgui_app_opt`` is the
variant that returns instead of panicking on launch failure.

Locators (``find_widget``, ``widget_exists``, ``widget_payload_field``,
``widget_rendered``) resolve via the same path keys the boost registry
uses; actions (``click``, ``type_text``, ``set_value``, ``drag``, ``focus``,
``open_widget``, ``close_widget``, ``reload``) post to the live-command
surface in :ref:`imgui_boost_runtime <stdlib_imgui_boost_runtime>` and apply
the matching ``AwaitModifiers``. Polling helpers (``wait_until``,
``wait_for_payload_value``, ``await_quiescent``) wrap the timeout/retry
loop so tests don't reinvent it.
