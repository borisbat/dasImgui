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

Run with `-project_root` pointing to the directory containing `modules/`:

```bash
daslang.exe -project_root . my_app.das
```

## Modules

| Module | Require | Description |
|--------|---------|-------------|
| `imgui` | `require imgui/imgui_boost` | Core Dear ImGui bindings |
| `imgui_app` | `require imgui_app` | GLFW + OpenGL3 application runtime |

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
