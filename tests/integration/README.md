# dasImgui integration tests

Two complementary test surfaces live in this directory.

## 1. dastest integration suite — daslang-native, full coverage

`test_*.das` files exercised by daslang's `dastest` runner. Each test spawns
`daslang-live` against a feature app under `../../examples/features/` (or
`../../examples/save_demo/`), drives it via `require imgui/imgui_playwright`,
and asserts behavior. This is the canonical regression suite.

Run from the daScript repo root:

```
daslang.exe dastest/dastest.das -- --test modules/dasImgui/tests/integration
```

Expect ~28 tests, ~130s wall time on a developer box (one daslang-live
subprocess per test, ~4-5s each).

## 2. Curl smoke — mechanism-level, tool-agnostic

`smoke_curl.ps1` (Windows) and `smoke_curl.sh` (POSIX) drive
`examples/save_demo/main.das` entirely via raw HTTP. NO playwright module,
NO dastest. They cover one happy path: spawn → ready → snapshot → click
SAVE_BTN → poll STATUS_TEXT.value == "saved" → shutdown.

```
powershell -ExecutionPolicy Bypass -File modules/dasImgui/tests/integration/smoke_curl.ps1
bash       modules/dasImgui/tests/integration/smoke_curl.sh
```

`smoke_curl.sh` requires `curl` and `jq` on PATH.

### Which one to run when

- **Most days**: the dastest suite. Full surface, fast feedback per test.
- **A dastest failure that doesn't make sense**: run the curl smoke. If it
  PASSes, the bug is somewhere in `widgets/imgui_playwright.das` or the
  test's wait/assertion logic. If the smoke FAILs too, the bug is deeper
  — daslang-live's dispatch, dasImgui's server-side `imgui_*` commands,
  or the playwright transport's HTTP layer.
- **Onboarding a non-daslang tool** (LLM-driven UI tester, headless probe,
  custom IDE integration, etc.): the curl smoke is the documented shape.
  Read it as the contract for "what a third-party client should do."

## 3. Recordings — APNG artifact generation

`record_*.das` files produce one tutorial-companion APNG each. They are
NOT in CI; they're one-shell driver scripts that spawn their own
`daslang-live` host via `with_recording_app`, post a narrate/click/drag
timeline, and save the APNG. APNGs live on an orphan `assets` branch
(see "APNG storage" below) and are referenced by the tutorial RST pages
under `doc/source/tutorials/`.

### The three scripts

| Script | Purpose | When to run |
|---|---|---|
| `rerecord_all.ps1` | Sequentially re-record every `record_*.das` driver. Writes APNGs to the gitignored `doc/source/_static/tutorials/`. ~20 min. | After cross-cutting visual changes (theme, font, narrate placement) or after touching multiple drivers. |
| `fetch_tutorial_apngs.ps1` / `.sh` | Pull current `origin/assets` APNGs into the local tutorial dir. Idempotent. | After a fresh clone, before `sphinx-build`. CI runs the `.sh` form automatically. |
| `publish_apngs_to_assets.ps1` | Spin up a fresh `assets` worktree, replace its APNG set with the working-tree APNGs, amend the orphan commit, force-push with `--force-with-lease`. | After eyeball-approving locally-generated APNGs and before merging the source-branch PR that references them. |

### Full publish workflow

The two-step record-then-publish split exists to keep a manual review
checkpoint between writing/running a driver and pushing binary artifacts
to a public branch:

```powershell
# One-time setup — point at your daslang build
$env:DASLANG_EXE = "D:/Work/daScript/bin/Release/daslang.exe"

# 1. Generate APNGs locally (whole sweep or single driver)
pwsh tests/integration/rerecord_all.ps1                # ~20 min, all drivers found via glob
# OR
daslang.exe -project_root . tests/integration/record_X.das

# 2. EYEBALL REVIEW. APNGs land at doc/source/_static/tutorials/.
#    Open in a browser, ffmpeg-extract key frames, etc. Iterate on the
#    driver until satisfied; rerun (1) per scene.
#
#    Frame extraction recipe (see skills/recording.md):
ffmpeg -i doc/source/_static/tutorials/X.apng \
    -vf "select=eq(n\,200)" -frames:v 1 -update 1 frame200.png -y

# 3. Publish — force-amend-push the orphan assets commit.
#    Ships the WHOLE working-tree APNG set, not just the one(s) you re-recorded.
#    Run fetch_tutorial_apngs.ps1 first if you want to keep untouched APNGs.
pwsh tests/integration/publish_apngs_to_assets.ps1

# 4. Push the source-branch PR (record_*.das + RST + index.rst).
#    CI's sphinx step fetches APNGs from origin/assets via .sh script.
git push -u origin <branch>
```

### Branch contract: `origin/assets`

`origin/assets` is an **orphan branch with exactly one commit**,
force-amend-pushed on every publish. Tip never has parents; GitHub GCs
the previous commit's blobs after ~2 weeks. Layout mirrors the source
repo: `doc/source/_static/tutorials/*.apng` plus a root `README.md`
documenting the contract.

Never merge anything into `assets`. Never expect history. PRs against
`assets` are nonsense — `publish_apngs_to_assets.ps1` is the only
mechanism that writes there.

### CI integration

`.github/workflows/docs.yml` runs `fetch_tutorial_apngs.sh` before
`daspkg install dasImgui (global)` so the daspkg copy picks up the
freshly-fetched binaries alongside the source. Sphinx then reads from
the daspkg-installed
`daslang-src/modules/dasImgui/doc/source/_static/tutorials/`.

CI uses `-W` (warnings-as-errors) on sphinx, so an RST referencing a
missing APNG fails the build. Implication for a new tutorial PR:
**APNGs must land on `origin/assets` before the source-branch PR can
merge** (or its docs CI will fail). Pair every new RST commit with a
prior publish step.

### Adding a new recording

For a new tutorial `foo`:

1. Write `examples/tutorial/foo.das` and `tests/integration/record_foo.das`
   (see [`../../skills/recording.md`](../../skills/recording.md) for the
   driver template).
2. `daslang.exe -project_root . tests/integration/record_foo.das` —
   produces `doc/source/_static/tutorials/foo.apng`.
3. Eyeball-review. ffmpeg-extract frames if needed.
4. Write `doc/source/tutorials/foo.rst` + add to `index.rst` toctree.
5. `publish_apngs_to_assets.ps1` — pushes APNG to `origin/assets`.
6. `git push -u origin <branch>` — source-branch PR with RST + driver.

The order matters: APNG on `assets` first, then source-branch PR. If
the PR is opened before the APNG lands, the docs CI run will fail.

Detailed driver-authoring guidance, pacing constants, menu-interaction
gotchas, and visual aid recipes live in
[`../../skills/recording.md`](../../skills/recording.md).

## Notes

- Tests are dastest-discovered by `test_*.das` filename. Files starting
  with `_` are skipped (see `feedback_dastest_underscore_skip`).
- The harness is `require imgui/imgui_playwright public`, declared in
  `widgets/imgui_playwright.das` and registered via `.das_module`.
- Feature apps used by `type_text`, `drag`, or other coroutine-based
  commands MUST call `advance_coroutines()` each frame — see the three
  `io_synth_*` / `await_quiescent` examples and `save_demo` for the pattern.
