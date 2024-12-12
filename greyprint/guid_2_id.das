options indenting = 4

// OLD das restrictions
options unsafe_table_lookup = false
options strict_smart_pointers = false
options relaxed_pointer_const = true


module guid_2_id

require instructions

require daslib/strings_boost

var guid_2_id : table<string; int>
var id_2_guid : table<int; string>
var guid_2_id_next = 1000

def reset_guids
    delete guid_2_id
    delete id_2_guid
    guid_2_id_next = 1000

def get_unique_id ( guid:string ) : int
    var id = 0
    get(guid_2_id, guid) <| $ ( val )
        id = val
    if id == 0
        id = guid_2_id_next++
        guid_2_id[guid] = id
        id_2_guid[id] = guid
    return id

def get_input_unique_id ( inst:Instruction?; inp:string ) : int
    return get_unique_id("INPUT {inst.id} {inp}")

def get_output_unique_id ( inst:Instruction?; outp:string ) : int
    return get_unique_id("OUTPUT {inst.id} {outp}")

def translate_input_output_id ( id:int; typ:string ) : tuple<inst:Instruction?; pin:string> const
    assert(id_2_guid |> key_exists(id))
    var note <- split(id_2_guid[id]," ")
    assert(note[0]==typ)
    let instr = (*g_CurrentProject)->find_instruction(note[1])
    assert(instr!=null)
    let val = [[auto instr, note[2]]]
    delete note
    return val
