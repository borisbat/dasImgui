options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_live_core public

//! Smoke test for the no-override trap detector in imgui_live_core.
//!
//! The trap: a tutorial author writes ``[export] def update()`` without
//! ``apply_synth_io_override()`` — synth mouse/key commands then queue
//! events that never drain (because imgui_synth_tick never fires).
//! Cursor sprite, mouse trail, and synth clicks silently no-op.
//!
//! Detection: any synth-event-queueing live_command calls
//! ``warn_if_synth_tick_missing``, which emits a one-shot ``LOG_WARNING``
//! when ``imgui_synth_tick`` has never run. Surface state is exposed via
//! ``synth_tick_run_count`` and ``synth_warned_no_override`` so tests can
//! verify the trigger without scraping stdout.

[test]
def test_warn_fires_when_tick_never_ran(t : T?) {
    //! Mirrors boost_basics-style trap: from clean state, the first
    //! synth-event-queueing call must flip the warned flag.
    reset_synth_warning_state()
    t |> equal(synth_tick_run_count(), 0, "tick count starts at 0 after reset")
    t |> equal(synth_warned_no_override(), false, "warned flag starts false after reset")

    warn_if_synth_tick_missing("imgui_mouse_play")

    t |> equal(synth_warned_no_override(), true, "warning fires when tick has never run")
    t |> equal(synth_tick_run_count(), 0, "warn call does not bump tick count")
}

[test]
def test_tick_suppresses_warning(t : T?) {
    //! Normal recording path: apply_synth_io_override() runs first, so
    //! when synth commands arrive the tick counter is already > 0 and the
    //! warning must NOT fire.
    reset_synth_warning_state()
    imgui_synth_tick()
    t |> equal(synth_tick_run_count(), 1, "imgui_synth_tick advances the run counter")

    warn_if_synth_tick_missing("imgui_mouse_play")

    t |> equal(synth_warned_no_override(), false, "warning does not fire when tick has already run")
}
