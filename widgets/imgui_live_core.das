options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_live_core shared public

// Synthetic IO bypass driver for ImGui — mouse + keyboard timelines + the
// per-frame imgui_synth_tick. Re-exported by imgui_live.

require imgui public
require imgui_app
require daslib/json public
require daslib/json_boost public
require daslib/utf8_utils
require live/live_commands
require live_host
require math
require strings

// ---------------------------------------------------------------------------
// Mouse driver
// ---------------------------------------------------------------------------

enum private MEKind {
    move
    button
    scroll
}

struct private MouseEvent {
    t_ms   : int    = 0
    kind   : MEKind = MEKind.move
    x      : float  = 0.0
    y      : float  = 0.0
    button : int    = 0
    action : int    = 0    // 1=press, 0=release
}

var private mouse_timeline   : array<MouseEvent>
var private mouse_play_start : float = 0.0
var private mouse_play_idx   : int   = 0
var private mouse_playing    : bool  = false
var private mouse_cursor_x   : float = 0.0
var private mouse_cursor_y   : float = 0.0
// Sticky: any synth event in this session flips this and arms the tick.
var public synth_cursor_owned : bool = false
// Cached waypoint for between-move interpolation. -1 = no prior move consumed.
var private last_move_x : float = 0.0
var private last_move_y : float = 0.0
var private last_move_t : int   = -1
// Last synthesized click — consumed by visual_aids paint_click_flash.
var public synth_click_button : int   = -1
var public synth_click_action : int   = 0    // 1 = press, 0 = release
var public synth_click_t      : float = -1.0
var private synth_held_buttons : table<int>

def private synth_cursor_pos(x, y : float) {
    mouse_cursor_x = x
    mouse_cursor_y = y
    synth_cursor_owned = true
    imgui_synth_mouse_pos(x, y)
}

def private synth_mouse_button(button, action : int) {
    // Emit cursor pos immediately before the button event so ImGui's
    // UpdateMouseInputs records `io.MouseClickedPos` at the synth coords
    // — without this prefix, the backend's earlier `AddMousePosEvent(real)`
    // would be the most-recently-drained pos when MouseClicked latches,
    // and IsItemHovered() at the synth widget would test false.
    if (synth_cursor_owned) {
        imgui_synth_mouse_pos(mouse_cursor_x, mouse_cursor_y)
    }
    imgui_synth_mouse_button(button, action == 1)
    if (action == 1) {
        synth_held_buttons |> insert(button)
    } else {
        synth_held_buttons |> erase(button)
    }
    synth_click_button = button
    synth_click_action = action
    synth_click_t      = get_uptime()
    synth_cursor_owned = true
}

def private release_held_buttons() {
    if (empty(synth_held_buttons)) return
    var held : array<int>
    held |> reserve(length(synth_held_buttons))
    for (b in keys(synth_held_buttons)) {
        held |> push(b)
    }
    for (b in held) {
        synth_mouse_button(b, 0)
    }
}

def public get_synth_cursor() : tuple<bool; float; float> {
    //! Current synth cursor as ``(owned, x, y)``; ``owned=true`` means visual_aids overlays should render against this position instead of ``GetMousePos()``.
    return (synth_cursor_owned, mouse_cursor_x, mouse_cursor_y)
}

def private reset_mouse_timeline() {
    mouse_timeline |> clear()
    mouse_play_idx = 0
    mouse_playing  = false
    last_move_x = mouse_cursor_x
    last_move_y = mouse_cursor_y
    last_move_t = -1
}

struct MousePosArgs {
    x : float = 0.0
    y : float = 0.0
}

[live_command(description="Teleport synthetic cursor via ImGui bypass. Args: x, y")]
def imgui_mouse_pos(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<MousePosArgs>)
    synth_cursor_pos(args.x, args.y)
    return JV((x = args.x, y = args.y))
}

struct MouseClickArgs {
    @optional button : int    = 0
    action           : string = "press"
}

[live_command(description="Synthetic mouse button via ImGui bypass. Args: button (0/1/2), action (press|release)")]
def imgui_mouse_click(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<MouseClickArgs>)
    var act : int
    if (args.action == "press") {
        act = 1
    } elif (args.action == "release") {
        act = 0
    } else {
        return JV((error = "invalid action; expected \"press\" or \"release\"", action = args.action))
    }
    synth_mouse_button(args.button, act)
    return JV((button = args.button, action = args.action))
}

struct MouseScrollArgs {
    x : float = 0.0
    y : float = 0.0
}

[live_command(description="Synthetic mouse scroll via ImGui bypass. Args: x, y (offsets)")]
def imgui_mouse_scroll(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<MouseScrollArgs>)
    imgui_synth_mouse_wheel(args.x, args.y)
    synth_cursor_owned = true
    return JV((x = args.x, y = args.y))
}

struct MouseMoveToArgs {
    x : float = 0.0
    y : float = 0.0
    @optional duration_ms : int = 250
}

[live_command(description="Animated cursor move to (x,y) over duration_ms via ImGui bypass. Linear interpolation.")]
def imgui_mouse_move_to(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<MouseMoveToArgs>)
    reset_mouse_timeline()
    mouse_timeline |> push(MouseEvent(t_ms = 0, kind = MEKind.move, x = mouse_cursor_x, y = mouse_cursor_y))
    mouse_timeline |> push(MouseEvent(t_ms = max(1, args.duration_ms), kind = MEKind.move, x = args.x, y = args.y))
    mouse_play_start = get_uptime()
    mouse_playing    = true
    return JV((duration_ms = args.duration_ms))
}

struct MouseEventWire {
    @optional t_ms   : int    = 0
    kind             : string = "move"
    @optional x      : float  = 0.0
    @optional y      : float  = 0.0
    @optional button : int    = 0
    @optional action : string = "press"
}

struct MousePlayArgs {
    events : array<MouseEventWire>
}

def public sort_mouse_play_events(var events : array<MouseEventWire>) {
    //! Sort wire-format mouse events ascending by ``t_ms`` in place — call before feeding ``imgui_mouse_play`` so the timeline drains in chronological order.
    events |> sort() $(a, b : MouseEventWire) {
        return a.t_ms < b.t_ms
    }
}

[live_command(description="Play a scripted mouse timeline via ImGui bypass. Args: events array of (t_ms, kind, x, y, button, action)")]
def imgui_mouse_play(input : JsonValue?) : JsonValue? {
    var args = from_JV(input, type<MousePlayArgs>)
    return JV((error = "no events")) if (empty(args.events))
    sort_mouse_play_events(args.events)
    reset_mouse_timeline()
    mouse_timeline |> reserve(length(args.events))
    for (w in args.events) {
        var ev = MouseEvent(t_ms = w.t_ms)
        if (w.kind == "move") {
            ev.kind = MEKind.move
            ev.x = w.x
            ev.y = w.y
        } elif (w.kind == "button") {
            ev.kind = MEKind.button
            ev.button = w.button
            if (w.action == "press") {
                ev.action = 1
            } elif (w.action == "release") {
                ev.action = 0
            } else {
                return JV((error = "invalid button action; expected \"press\" or \"release\"", action = w.action))
            }
        } elif (w.kind == "scroll") {
            ev.kind = MEKind.scroll
            ev.x = w.x
            ev.y = w.y
        } else {
            return JV((error = "unknown event kind", kind = w.kind))
        }
        mouse_timeline |> push(ev)
    }
    mouse_play_start = get_uptime()
    mouse_playing    = true
    return JV((queued = length(mouse_timeline)))
}

[live_command(description="Stop synthetic mouse playback (ImGui bypass) and release any held buttons.")]
def imgui_mouse_stop(input : JsonValue?) : JsonValue? {
    let was_playing = mouse_playing
    let released    = length(synth_held_buttons)
    release_held_buttons()
    reset_mouse_timeline()
    return JV((stopped = was_playing, released = released))
}

struct MouseStatusResult {
    playing      : bool
    elapsed_ms   : int
    cursor_x     : float
    cursor_y     : float
    queue_idx    : int
    queue_total  : int
    held_count   : int
    cursor_owned : bool
}

[live_command(description="ImGui-bypass mouse playback status.")]
def imgui_mouse_status(input : JsonValue?) : JsonValue? {
    let elapsed = mouse_playing ? int((get_uptime() - mouse_play_start) * 1000.0) : 0
    return JV(MouseStatusResult(
        playing      = mouse_playing,
        elapsed_ms   = elapsed,
        cursor_x     = mouse_cursor_x,
        cursor_y     = mouse_cursor_y,
        queue_idx    = mouse_play_idx,
        queue_total  = length(mouse_timeline),
        held_count   = length(synth_held_buttons),
        cursor_owned = synth_cursor_owned
    ))
}

def private advance_mouse_timeline() {
    return if (!mouse_playing)
    let now_ms = int((get_uptime() - mouse_play_start) * 1000.0)
    while (mouse_play_idx < length(mouse_timeline)) {
        let ev = mouse_timeline[mouse_play_idx]
        break if (ev.t_ms > now_ms)
        if (ev.kind == MEKind.move) {
            synth_cursor_pos(ev.x, ev.y)
            last_move_x = ev.x
            last_move_y = ev.y
            last_move_t = ev.t_ms
        } elif (ev.kind == MEKind.button) {
            synth_mouse_button(ev.button, ev.action)
        } elif (ev.kind == MEKind.scroll) {
            imgui_synth_mouse_wheel(ev.x, ev.y)
        }
        mouse_play_idx++
    }
    if (mouse_play_idx >= length(mouse_timeline)) {
        mouse_playing = false
        return
    }
    // Between waypoints: lerp from the last consumed move toward the next.
    if (last_move_t >= 0) {
        var next_move_idx = mouse_play_idx
        while (next_move_idx < length(mouse_timeline) && mouse_timeline[next_move_idx].kind != MEKind.move) {
            next_move_idx++
        }
        if (next_move_idx < length(mouse_timeline)) {
            let nm = mouse_timeline[next_move_idx]
            let span = nm.t_ms - last_move_t
            if (span > 0) {
                var alpha = float(now_ms - last_move_t) / float(span)
                if (alpha < 0.0) { alpha = 0.0; }
                if (alpha > 1.0) { alpha = 1.0; }
                let x = last_move_x + (nm.x - last_move_x) * alpha
                let y = last_move_y + (nm.y - last_move_y) * alpha
                synth_cursor_pos(x, y)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Keyboard driver
// ---------------------------------------------------------------------------
//
// State is keyed by ImGuiKey (int), NOT GLFW_KEY_*. ASCII translation tables
// resolve characters to ImGuiKey values directly — io.AddKeyEvent receives
// ImGuiKey, no GLFW indirection.

enum private KEKind {
    press
    release
    char_
}

struct private KeyEvent {
    t_ms      : int    = 0
    kind      : KEKind = KEKind.press
    key       : int    = 0    // ImGuiKey value (cast to int for storage)
    codepoint : uint   = 0u
}

var private key_timeline   : array<KeyEvent>
var private key_play_start : float = 0.0
var private key_play_idx   : int   = 0
var private key_playing    : bool  = false

// Public state read by visual_aids' keycap HUD. Keyed by ImGuiKey.
var public synth_held_keys        : table<int>        //! set of currently-held ImGuiKey values
var public synth_last_keycode     : int   = 0         //! last ImGuiKey synth-pressed; 0 = none
var public synth_last_keycode_t   : float = -1.0
var public synth_last_codepoint   : uint  = 0u
var public synth_last_codepoint_t : float = -1.0

def private mod_alias_for_side_key(key : int) : int {
    // Return ImGuiMod_* alias for a side-mod key (LeftCtrl → ImGuiMod_Ctrl) or 0.
    // ImGui's IsKeyDown(ImGuiMod_Ctrl) / io.KeyCtrl / Shortcut() consult the alias key —
    // emitting only the side key leaves the alias unset.
    if (key == int(ImGuiKey.LeftCtrl)  || key == int(ImGuiKey.RightCtrl)) return int(ImGuiKey.ImGuiMod_Ctrl)
    if (key == int(ImGuiKey.LeftShift) || key == int(ImGuiKey.RightShift)) return int(ImGuiKey.ImGuiMod_Shift)
    if (key == int(ImGuiKey.LeftAlt)   || key == int(ImGuiKey.RightAlt)) return int(ImGuiKey.ImGuiMod_Alt)
    if (key == int(ImGuiKey.LeftSuper) || key == int(ImGuiKey.RightSuper)) return int(ImGuiKey.ImGuiMod_Super)
    return 0
}

def private synth_key_press(key : int) {
    imgui_synth_key(key, true)
    synth_held_keys |> insert(key)
    let mod_alias = mod_alias_for_side_key(key)
    if (mod_alias != 0) {
        imgui_synth_key(mod_alias, true)
        synth_held_keys |> insert(mod_alias)
    }
    synth_last_keycode   = key
    synth_last_keycode_t = get_uptime()
}

def private synth_key_release(key : int) {
    imgui_synth_key(key, false)
    synth_held_keys |> erase(key)
    let mod_alias = mod_alias_for_side_key(key)
    if (mod_alias != 0) {
        imgui_synth_key(mod_alias, false)
        synth_held_keys |> erase(mod_alias)
    }
}

def private synth_char(codepoint : uint) {
    imgui_synth_input_char(codepoint)
    synth_last_codepoint   = codepoint
    synth_last_codepoint_t = get_uptime()
}

def public get_synth_keys() : tuple<bool; uint; float> {
    //! Current synth-key state as ``(active, last_codepoint, last_codepoint_t)``; visual_aids polls this each frame to detect newly-landed codepoints.
    return (key_playing, synth_last_codepoint, synth_last_codepoint_t)
}

def private reset_key_timeline() {
    key_timeline |> clear()
    key_play_idx = 0
    key_playing  = false
}

def private release_held_keys() {
    if (empty(synth_held_keys)) return
    var held : array<int>
    held |> reserve(length(synth_held_keys))
    for (k in keys(synth_held_keys)) {
        held |> push(k)
    }
    for (k in held) {
        synth_key_release(k)
    }
}

// --- ASCII translation tables (resolve to ImGuiKey values) ---

def private mod_name_to_key(name : string) : int {
    if (name == "Ctrl" || name == "Control") return int(ImGuiKey.LeftCtrl)
    if (name == "Shift") return int(ImGuiKey.LeftShift)
    if (name == "Alt") return int(ImGuiKey.LeftAlt)
    if (name == "Super" || name == "Cmd" || name == "Meta") return int(ImGuiKey.LeftSuper)
    return 0
}

def private needs_shift_ascii(c : int) : bool {
    if (c >= int('A') && c <= int('Z')) return true   // nolint:PERF014
    return (c == int('~') || c == int('!') || c == int('@') || c == int('#')
         || c == int('$') || c == int('%') || c == int('^') || c == int('&')
         || c == int('*') || c == int('(') || c == int(')') || c == int('_')
         || c == int('+') || c == int('{') || c == int('}') || c == int('|')
         || c == int(':') || c == int('"') || c == int('<') || c == int('>')
         || c == int('?'))
}

def private base_key_ascii(c : int) : int {
    // Returns the ImGuiKey value (as int) for the base key producing `c` on a US layout.
    // Shift handling layered on top in imgui_key_type; both letter cases share one ImGuiKey.
    // ImGuiKey.A=546 .. ImGuiKey.Z=571 ; ImGuiKey._0=536 .. ImGuiKey._9=545 ;
    // digit-prefixed enum values don't parse in daslang (`.0` reads as a
    // float literal), so we anchor the digit base on `ImGuiKey.A - 10`.
    let key_a = int(ImGuiKey.A)
    let key_0 = key_a - 10
    if (c >= int('A') && c <= int('Z')) return key_a + (c - int('A'))   // nolint:PERF014
    if (c >= int('a') && c <= int('z')) return key_a + (c - int('a'))   // nolint:PERF014
    if (c >= int('0') && c <= int('9')) return key_0 + (c - int('0'))   // nolint:PERF014
    // shifted digit row: ! @ # $ % ^ & * ( ) → keys 1 2 3 4 5 6 7 8 9 0
    if (c == int('!')) return key_0 + 1
    if (c == int('@')) return key_0 + 2
    if (c == int('#')) return key_0 + 3
    if (c == int('$')) return key_0 + 4
    if (c == int('%')) return key_0 + 5
    if (c == int('^')) return key_0 + 6
    if (c == int('&')) return key_0 + 7
    if (c == int('*')) return key_0 + 8
    if (c == int('(')) return key_0 + 9
    if (c == int(')')) return key_0
    // punctuation
    if (c == int(' ')) return int(ImGuiKey.Space)
    if (c == int('\n')) return int(ImGuiKey.Enter)
    if (c == int('\t')) return int(ImGuiKey.Tab)
    if (c == int(',') || c == int('<')) return int(ImGuiKey.Comma)
    if (c == int('.') || c == int('>')) return int(ImGuiKey.Period)
    if (c == int('/') || c == int('?')) return int(ImGuiKey.Slash)
    if (c == int(';') || c == int(':')) return int(ImGuiKey.Semicolon)
    if (c == int('\'') || c == int('"')) return int(ImGuiKey.Apostrophe)
    if (c == int('-') || c == int('_')) return int(ImGuiKey.Minus)
    if (c == int('=') || c == int('+')) return int(ImGuiKey.Equal)
    if (c == int('[') || c == int('{')) return int(ImGuiKey.LeftBracket)
    if (c == int(']') || c == int('}')) return int(ImGuiKey.RightBracket)
    if (c == int('\\') || c == int('|')) return int(ImGuiKey.Backslash)
    if (c == int('`') || c == int('~')) return int(ImGuiKey.GraveAccent)
    return 0
}

struct KeyPressArgs {
    key : int = 0   // ImGuiKey value (cast to int over the wire)
}

[live_command(description="Synthetic key press via ImGui bypass. Args: key (ImGuiKey int)")]
def imgui_key_press(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<KeyPressArgs>)
    return JV((error = "missing key")) if (args.key == 0)
    synth_key_press(args.key)
    return JV((key = args.key, action = "press"))
}

[live_command(description="Synthetic key release via ImGui bypass. Args: key (ImGuiKey int)")]
def imgui_key_release(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<KeyPressArgs>)
    return JV((error = "missing key")) if (args.key == 0)
    synth_key_release(args.key)
    return JV((key = args.key, action = "release"))
}

struct KeyCharArgs {
    codepoint : uint = 0u
}

[live_command(description="Synthetic Unicode char via ImGui bypass. Args: codepoint")]
def imgui_key_char(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<KeyCharArgs>)
    return JV((error = "missing codepoint")) if (args.codepoint == 0u)
    synth_char(args.codepoint)
    return JV((codepoint = args.codepoint))
}

struct KeyTypeArgs {
    text                       : string = ""
    @optional total_duration_s : float  = 0.0
    @optional per_char_ms      : int    = 60
}

[live_command(description="Stream text as synthetic key+char events via ImGui bypass. Args: text, total_duration_s? | per_char_ms?")]
def imgui_key_type(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<KeyTypeArgs>)
    return JV((error = "empty text")) if (empty(args.text))
    let cps <- utf8_decode(args.text)
    let n_chars = length(cps)
    var per_char_ms = max(1, args.per_char_ms)
    if (args.total_duration_s > 0.0f) {
        per_char_ms = max(1, int(args.total_duration_s * 1000.0f) / max(1, n_chars))
    }
    reset_key_timeline()
    var t = 0
    key_timeline |> reserve(n_chars * 5)
    let shift_key = int(ImGuiKey.LeftShift)
    for (cp in cps) {
        if (cp < 0x80u) {
            let c     = int(cp)
            let k     = base_key_ascii(c)
            let shift = needs_shift_ascii(c)
            if (shift) {
                key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.press, key = shift_key))
            }
            if (k != 0) {
                key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.press, key = k))
            }
            key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.char_, codepoint = cp))
            if (k != 0) {
                key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.release, key = k))
            }
            if (shift) {
                key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.release, key = shift_key))
            }
        } else {
            key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.char_, codepoint = cp))
        }
        t += per_char_ms
    }
    key_play_start = get_uptime()
    key_playing    = true
    return JV((queued = length(key_timeline), per_char_ms = per_char_ms, chars = n_chars))
}

struct KeyChordArgs {
    mods : array<string>
    key  : string = ""
}

[live_command(description="Synthetic chord via ImGui bypass. Args: mods (\"Ctrl\"|\"Shift\"|\"Alt\"|\"Super\"), key (single ASCII char)")]
def imgui_key_chord(input : JsonValue?) : JsonValue? {
    let args = from_JV(input, type<KeyChordArgs>)
    return JV((error = "missing key")) if (empty(args.key))
    var target_key = 0
    if (length(args.key) == 1) {
        target_key = base_key_ascii(int(first_character(args.key)))
    }
    return JV((error = "unsupported chord key", key = args.key)) if (target_key == 0)
    // Validate mod names up front.
    for (m in args.mods) {
        return JV((error = "unknown modifier", modifier = m)) if (mod_name_to_key(m) == 0)
    }
    reset_key_timeline()
    key_timeline |> reserve(length(args.mods) + 2)
    var t = 0
    // Press the side-mod key — synth_key_press auto-pairs the ImGuiMod_*
    // alias, so Shortcut() routing sees the chord (mirrors
    // imgui_test_engine ApplyInputToImGuiContext mod-event pairing).
    for (m in args.mods) {
        let mkc = mod_name_to_key(m)
        key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.press, key = mkc))
        t += 8
    }
    key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.press, key = target_key))
    t += 16
    key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.release, key = target_key))
    t += 8
    var i = length(args.mods) - 1
    while (i >= 0) {
        let m = args.mods[i]
        let mkc = mod_name_to_key(m)
        key_timeline |> push(KeyEvent(t_ms = t, kind = KEKind.release, key = mkc))
        t += 8
        i--
    }
    key_play_start = get_uptime()
    key_playing    = true
    return JV((queued = length(key_timeline)))
}

struct KeyEventWire {
    @optional t_ms      : int    = 0
    kind                : string = "press"   // "press" | "release" | "char"
    @optional key       : int    = 0
    @optional codepoint : uint   = 0u
}

struct KeyPlayArgs {
    events : array<KeyEventWire>
}

def public sort_key_play_events(var events : array<KeyEventWire>) {
    //! Sort wire-format key events ascending by ``t_ms`` in place — call before feeding ``imgui_key_play`` so the timeline drains in chronological order.
    events |> sort() $(a, b : KeyEventWire) {
        return a.t_ms < b.t_ms
    }
}

[live_command(description="Play a scripted key/char timeline via ImGui bypass. Args: events array of (t_ms, kind, key, codepoint)")]
def imgui_key_play(input : JsonValue?) : JsonValue? {
    var args = from_JV(input, type<KeyPlayArgs>)
    return JV((error = "no events")) if (empty(args.events))
    sort_key_play_events(args.events)
    reset_key_timeline()
    key_timeline |> reserve(length(args.events))
    for (w in args.events) {
        var ev = KeyEvent(t_ms = w.t_ms, key = w.key, codepoint = w.codepoint)
        if (w.kind == "press") {
            ev.kind = KEKind.press
        } elif (w.kind == "release") {
            ev.kind = KEKind.release
        } elif (w.kind == "char") {
            ev.kind = KEKind.char_
        } else {
            return JV((error = "unknown event kind", kind = w.kind))
        }
        key_timeline |> push(ev)
    }
    key_play_start = get_uptime()
    key_playing    = true
    return JV((queued = length(key_timeline)))
}

[live_command(description="Stop synthetic key playback (ImGui bypass) and release any held keys.")]
def imgui_key_stop(input : JsonValue?) : JsonValue? {
    let was_playing = key_playing
    let released    = length(synth_held_keys)
    release_held_keys()
    reset_key_timeline()
    return JV((stopped = was_playing, released = released))
}

struct KeyStatusResult {
    playing        : bool  //! true while a recorded key timeline is being replayed.
    elapsed_ms     : int   //! milliseconds since timeline playback began (0 when idle).
    queue_idx      : int   //! index of the next pending event in the timeline.
    queue_total    : int   //! total number of events in the active timeline.
    held_count     : int   //! number of synthetic keys currently held down.
    last_keycode   : int   //! ImGuiKey value (renamed from "key" so visual_aids can read uniformly)
    last_codepoint : uint  //! most recent codepoint pushed via AddInputCharacter.
}

[live_command(description="ImGui-bypass keyboard playback status.")]
def imgui_key_status(input : JsonValue?) : JsonValue? {
    let elapsed = key_playing ? int((get_uptime() - key_play_start) * 1000.0) : 0
    return JV(KeyStatusResult(
        playing        = key_playing,
        elapsed_ms     = elapsed,
        queue_idx      = key_play_idx,
        queue_total    = length(key_timeline),
        held_count     = length(synth_held_keys),
        last_keycode   = synth_last_keycode,
        last_codepoint = synth_last_codepoint
    ))
}

def private advance_key_timeline() {
    return if (!key_playing)
    let now_ms = int((get_uptime() - key_play_start) * 1000.0)
    while (key_play_idx < length(key_timeline)) {
        let ev = key_timeline[key_play_idx]
        break if (ev.t_ms > now_ms)
        if (ev.kind == KEKind.press) {
            synth_key_press(ev.key)
        } elif (ev.kind == KEKind.release) {
            synth_key_release(ev.key)
        } elif (ev.kind == KEKind.char_) {
            synth_char(ev.codepoint)
        }
        key_play_idx++
    }
    if (key_play_idx >= length(key_timeline)) {
        key_playing = false
    }
}

// ---------------------------------------------------------------------------
// Per-frame entry point
// ---------------------------------------------------------------------------

def public imgui_synth_tick() {
    //! Per-frame entry point — advance synth mouse/key timelines and re-assert held state. Call between the backend's ``*_NewFrame()`` and ``ImGui::NewFrame()``; no-op when no synth command has fired.
    advance_mouse_timeline()
    advance_key_timeline()
    let synth_armed = synth_cursor_owned || !empty(synth_held_keys) || !empty(synth_held_buttons)
    return if (!synth_armed)
    // Re-assert held state. Idempotent for ImGui — repeated AddKeyEvent /
    // AddMouseButtonEvent with the same state are dedupe'd on the drain.
    if (synth_cursor_owned) {
        imgui_synth_mouse_pos(mouse_cursor_x, mouse_cursor_y)
    }
    for (b in keys(synth_held_buttons)) {
        imgui_synth_mouse_button(b, true)
    }
    for (k in keys(synth_held_keys)) {
        imgui_synth_key(k, true)
    }
}
