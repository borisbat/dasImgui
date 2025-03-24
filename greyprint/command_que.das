options gen2
options indenting = 4

module command_que

require daslib/strings_boost

var g_que : array<lambda<() : void>>

def post_event(var evt : lambda<() : void>) {
    g_que |> emplace(evt)
}

def post_invoke_que {
    while (!g_que |> empty()) {
        var new_que <- g_que
        for (ev in new_que) {
            invoke(ev)
        }
        delete new_que
    }
}
