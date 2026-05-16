# dasImgui

[Dear ImGui](https://github.com/ocornut/imgui) bindings for [daslang](https://dascript.org/).

Provides the `imgui` and `imgui_app` modules for building GUI applications with daslang.

## Install

```bash
daslang.exe utils/daspkg/main.das -- install github.com/borisbat/dasImgui
```

Or add to your project's `.das_package`:

```das
[export]
def dependencies(version : string) {
    require_package("github.com/borisbat/dasImgui")
}
```

Then run `daspkg install`.

## Build

The C++ build step runs automatically during `daspkg install`. To rebuild manually:

```bash
daspkg build dasImgui
```

Or with CMake directly:

```bash
cmake -B modules/dasImgui/_build -S modules/dasImgui -DDASLANG_DIR=<path-to-daslang-root>
cmake --build modules/dasImgui/_build --config Release
```

### Requirements

- daslang SDK (built with `DAS_GLFW_DISABLED=OFF`)
- CMake 3.16+
- C++17 compiler (MSVC, GCC, Clang)
- OpenGL

## Usage

The smallest embedding, using the gen1 ``imgui_app`` harness:

```das
options gen2

require imgui_app
require imgui/imgui_boost
require glfw/glfw_boost

[export]
def main() {
    imgui_app("My App") <| $() {
        NewFrame()
        if (Begin("Hello", null, ImGuiWindowFlags.None)) {
            Text("Hello from daslang!")
        }
        End()
        Render()
    }
}
```

For real applications, use the v2 boost surface — block-arg `window(...)`
containers, auto-emitted state structs, live-reload, and a JSON-driven
command surface. See the [dasImgui tutorials](doc/source/tutorials/index.rst)
starting at `boost_basics` for a complete walkthrough.

For examples and tests, use `imgui/imgui_harness` — it hides the GLFW/GL
backend boilerplate behind five helpers and re-exports the backend-agnostic
v2 stack, so the test file is purely widget logic:

```das
options gen2

require imgui/imgui_harness

[export] def init() {
    harness_init("My Example", 800, 600)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
}

[export] def update() {
    if (!harness_begin_frame()) return
    harness_new_frame()
    window(MAIN_WIN, (text = "Hello")) {
        text("Hello from daslang!")
    }
    harness_end_frame()
}

[export] def shutdown() { harness_shutdown() }

[export] def main() {
    init()
    while (!exit_requested()) { update() }
    shutdown()
}
```

Same script runs headless (no window, no GL context) by passing
`--headless` after the daslang `--` separator:

```bash
daslang.exe my_example.das -- --headless --headless-frames=600
```

Headless mode skips the GLFW + OpenGL chain entirely (the harness uses a
parallel `imguiAppHeadless.shared_module` C++ backend with a CPU-only
font atlas). `--headless-frames=N` auto-exits after `N` frames; omit it
when the script's own logic calls `request_exit()`. See
[doc/source/tutorials/harness_headless_mode.rst](doc/source/tutorials/harness_headless_mode.rst)
for what gets dispatched in either mode and the limits (`screenshot` /
`record_*` and the live-API HTTP endpoint stay windowed-only).

Run with `-project_root` pointing to the directory containing `modules/`:

```bash
daslang.exe -project_root . my_app.das
```

## Modules

| Module | Require | Description |
|--------|---------|-------------|
| `imgui` | `require imgui/imgui_boost` | Core Dear ImGui bindings |
| `imgui_app` | `require imgui_app` | GLFW + OpenGL3 application runtime |
| `imgui_app_headless` | (private, used by harness) | Display-less ImGui backend (CPU font atlas, no GLFW, no GL) for `--headless` runs |
| `imgui_harness` | `require imgui/imgui_harness` | Canonical wrapper for examples/tests — hides GLFW/GL boilerplate, re-exports the backend-agnostic v2 stack, dispatches windowed vs `--headless` at runtime |

## Examples

- `example/imgui_demo.das` — full ImGui demo window
- `example/imgui_opengl2.das` — minimal OpenGL example

## imgui version

v1.90.6-docking (fetched via CMake FetchContent at build time).

## Documentation

Local build (HTML site under `doc/_build/html/`):

```bash
daslang.exe utils/imgui2rst.das -- --detail_output doc/source/stdlib/generated
sphinx-build -b html doc/source doc/_build/html
```

The first step runs the RST emitter (parallel to daslang's `das2rst`); the
`--detail_output` flag points the per-function `//!` detail files at this
tree's `generated/detail/` so module pages render the captured docstrings.
The second step invokes Sphinx.

`doc/source/stdlib/generated/` and `doc/_build/` are gitignored. Tracked
inputs are `doc/source/conf.py`, `daslang.py`, `index.rst`, the section
landings (`sec_*.rst`), `external_types.rst`, `handmade/module-*.rst`,
`tutorials/`, and the emitter itself (`utils/imgui2rst.das`).

Re-run `utils/imgui2rst.das` whenever a public `//!` comment changes. The
forthcoming `.github/workflows/docs.yml` CI gate will verify no `// stub`
placeholders remain in `handmade/` and that Sphinx builds clean under `-W`.

The published site (once gh-pages is wired) will be linked from the main
[daslang documentation](https://dascript.org/).

## License

MIT
