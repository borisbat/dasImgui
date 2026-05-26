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

## 3. Recordings — MP4 artifact generation

`record_*.das` files produce one tutorial-companion video each. They
are NOT in CI; they're one-shell driver scripts that spawn their own
`daslang-live` host via `with_recording_app`, post a narrate/click/drag
timeline, and save an `.apng`. A single ffmpeg pass converts each
`.apng` to the shipped `.mp4` (~300× smaller). The `.mp4` files live
in-tree under `doc/source/_static/tutorials/` (~5 MB total for the full
set) and are referenced by tutorial RST pages.

### The script

| Script | Purpose | When to run |
|---|---|---|
| `rerecord_all.ps1` | Sequentially re-record every `record_*.das` driver. Writes intermediate APNGs to the gitignored `doc/source/_static/tutorials/`. ~20 min. | After cross-cutting visual changes (theme, font, narrate placement) or after touching multiple drivers. |

After re-recording, convert APNGs to MP4 via ffmpeg (the deliverables).

### Full workflow

```powershell
# One-time setup — point at your daslang build
$env:DASLANG_EXE = "D:/Work/daScript/bin/Release/daslang.exe"

# 1. Generate APNGs locally (whole sweep or single driver)
pwsh tests/integration/rerecord_all.ps1                # ~20 min, all drivers found via glob
# OR
daslang.exe -project_root . tests/integration/record_X.das

# 2. EYEBALL REVIEW the .apng output before converting.
#    ffmpeg-extract frames if needed:
ffmpeg -i doc/source/_static/tutorials/X.apng \
    -vf "select=eq(n\,200)" -frames:v 1 -update 1 frame200.png -y

# 3. Convert APNG → MP4 (the deliverable).
#    For a single recording:
ffmpeg -y -loglevel error -i doc/source/_static/tutorials/X.apng \
    -c:v libx264 -crf 23 -pix_fmt yuv420p -movflags +faststart \
    doc/source/_static/tutorials/X.mp4

#    Bulk (all APNGs in the dir):
cd doc/source/_static/tutorials
for f in *.apng; do
    base="${f%.apng}"
    ffmpeg -y -loglevel error -i "$f" -c:v libx264 -crf 23 \
           -pix_fmt yuv420p -movflags +faststart "$base.mp4"
done

# 4. git add the MP4(s) and push the source-branch PR.
git add doc/source/_static/tutorials/X.mp4
git push -u origin <branch>
```

### CI integration

`.github/workflows/docs.yml` checks out the source — `.mp4` files are
already in the tree, no fetch step. CI uses `-W` (warnings-as-errors)
on sphinx, so an RST `<video>` block referencing a missing `.mp4` fails
the build. Implication for a new tutorial PR: commit the `.mp4`
ahead of the RST cite to keep CI passing.

### Adding a new recording

For a new tutorial `foo`:

1. Write `examples/tutorial/foo.das` and `tests/integration/record_foo.das`
   (see [`../../skills/recording.md`](../../skills/recording.md) for the
   driver template).
2. `daslang.exe -project_root . tests/integration/record_foo.das` —
   produces `doc/source/_static/tutorials/foo.apng` (gitignored).
3. Eyeball-review. ffmpeg-extract frames if needed.
4. ffmpeg-convert `foo.apng` → `foo.mp4` (see step 3 of the workflow above).
5. Write `doc/source/tutorials/foo.rst` + add to `index.rst` toctree.
6. `git add foo.mp4 record_foo.das foo.rst index.rst` + push.

### Historical note: orphan `assets` branch

Before the MP4 migration (PR-MP4), the 37-tutorial APNG set totaled
~1.7 GB and lived on an orphan `assets` branch (force-amend-pushed each
sweep). The branch is now dead — at ~5 MB of MP4 for the full set, the
source repo absorbs the deliverables cleanly. The `origin/assets` ref
can be deleted; nothing references it.

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
