# Repo-managed git hooks

Tracked hooks that mirror CI checks. Cross-platform: Linux, macOS, Windows (Git Bash).

## Enable (once per clone)

```sh
git config core.hooksPath .githooks
```

Reverts via `git config --unset core.hooksPath`. Skip once with `git push --no-verify`.

### Windows notes

- Git for Windows ships Git Bash — the `#!/usr/bin/env bash` shebang works out of the box. No extra install needed.
- If you use PowerShell or `cmd` for `git push`, that's fine — git invokes the hook through its own shell, not yours.
- File-mode permissions are ignored on Windows; just having the file in `.githooks/` is enough.

### Linux / macOS

Hooks must be executable. Cloning preserves the executable bit (it's set in the repo via `git update-index --chmod=+x`). If you ever lose it locally:

```sh
chmod +x .githooks/*
```

## Hooks

- **pre-push** — formatter (`--verify` on the whole tree) + lint on pushed `.das` files. Mirrors `.github/workflows/docs.yml`.

## Requirements

dasImgui is a module — the `daslang` binary lives in your sibling daslang checkout. The script auto-detects:

- `../daScript/bin/Release/daslang.exe` / `bin/Debug/daslang.exe` (Windows MSVC)
- `../daScript/bin/daslang` / `bin/daslang.exe` (Linux/macOS/MSYS)
- `../daScript/build/daslang`, `build/bin/daslang`
- `../daslang/bin/...` (alt directory name)
- `daslang` on `PATH`

Build daslang before pushing:

```sh
cd ../daScript && cmake --build build --target daslang
```

Override the resolved path:

```sh
DASLANG=/custom/path/daslang.exe git push
```

Override the daslang source tree (needed for `utils/lint/main.das` and `utils/das-fmt/dasfmt.das`):

```sh
DASLANG_SRC=/custom/path/daScript git push
```
