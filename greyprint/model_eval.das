options indenting = 4

// OLD das restrictions
options unsafe_table_lookup = false
options strict_smart_pointers = false
options relaxed_pointer_const = true


module model_eval

require instructions public

require produce

require daslib/strings_boost
require daslib/static_let
require daslib/algorithm
require daslib/defer

def mark_instruction ( inst:Instruction?; var used:table<Instruction?;bool>; action:string )
    if used |> key_exists(inst)
        return
    if inst.action!=action
        return
    used[inst] = true
    for inp in inst.pins.inputs
        if inp.src!=null
            mark_instruction(inp.src, used, action)

def collect_instructions(action:string)
    var used : table<Instruction?;bool>
    for inst in g_CurrentProject.instructions
        if inst.flags.Output
            var ireval : array<Instruction?>
            mark_instruction(inst, used, action)
    var reval : array<Instruction?>
    var any_added = true
    var placed : table<Instruction?;bool>
    while any_added
        any_added = false
        for inst in g_CurrentProject.instructions
            if placed |> key_exists(inst)
                continue
            if used |> key_exists(inst)
                var allPins = true
                for inp in inst.pins.inputs
                    if inp.src!=null
                        if !placed |> key_exists(inp.src)
                            allPins = false
                            break
                if allPins
                    placed[inst] = true
                    reval |> push(inst)
                    any_added = true
    delete used
    delete placed
    reverse(reval)
    return <- reval


def assign_registers ( var reval:array<Instruction?> ) : int
    var reg_total = 0
    for inst in reval
        for outp in inst.pins.outputs
            outp.reg = reg_total ++
    return reg_total ++

def need_to_produce_delete(outptype:string)
    return outptype=="surface"

def reg_type ( outptype:string )
    static_let <|
        let reg_type <- {{
            "scalar" => "float";
            "vector2" => "float2";
            "vector3" => "float3";
            "vector4" => "float4";
            "surface" => "Surface"
        }}
    return reg_type?[outptype] ?? "unknown"

def produce_eval ( var reval:array<Instruction?>; reg_total:int )
    // note: we are generating everything in reverse order
    // that very its very obvious when to 'delete'
    var reg_used : array<bool>
    reg_used |> resize(reg_total)
    var eval:array<string>
    for inst in reval
        // first time seeing means last its used, and needs to be deleted
        var inp_regs : array<int>
        for inp in inst.pins.inputs
            if inp.src != null
                let oidx = inp.src->output_index(inp.output)
                assert(oidx!=-1)
                var outp & = unsafe(inp.src.pins.outputs[oidx])
                let reg = outp.reg
                inp_regs |> push(reg)
                if !reg_used[reg]
                    reg_used[reg] = true
                    if need_to_produce_delete(outp._type)
                        eval |> push("    delete_{outp._type}({to_reg(reg)})")
            else
                inp_regs |> push(-1)
        // preview
        for outp in inst.pins.outputs
            if outp.preview
                eval |> push("    preview({to_reg(outp.reg)},\"{inst.name}\",\"{inst.id}\",\"{outp.name}\")")
        // instruction produces generation, we invert again
        var ipod <- inst->produce(inp_regs)
        reverse(ipod)
        for ib in ipod
            eval |> push("    {ib}")
        delete ipod
        // register declaration
        for outp in inst.pins.outputs
            eval |> push("    var {to_reg(outp.reg)} : {reg_type(outp._type)}")
        // comment
        let irt = join([{for r in inp_regs; "{to_reg(r)}"}],",")
        let ort = join([{for r in inst.pins.outputs; "{to_reg(r.reg)}"}],",")
        // eval |> push("    // eval {inst.__rtti} -> {inst.name}:{inst.id} [[pins.inputs {irt}]] [[pins.outputs {ort}]]")
    if length(reval)==0
        eval |> push("    pass")
    // now back to normal order
    reverse(eval)
    return <- eval

def produce_eval(action:string="")
    for inst in g_CurrentProject.instructions
        for outp in inst.pins.outputs
            outp.reg = -1
    var reval <- collect_instructions(action)
    let nreg = assign_registers(reval)
    return <- produce_eval(reval, nreg)

def produce_project_text
    let st = build_string() <| $ (var writer)
        writer |> write("options fusion=false\n")
        writer |> write("require instructions\n")
        writer |> write("require model\n")
        writer |> write("require math\n")
        writer |> write("\n")
        for act,actname in keys(g_CurrentProject.actions),values(g_CurrentProject.actions)
            if true
                var inscope pins <- collect_action_pins(g_CurrentProject,act)
                write(writer,"// {actname}\n")
                write(writer,"def fn_{decorate_name(act)}(")
                var eidx = 0
                for inp in pins.inputs
                    eidx ++
                    if eidx != 1
                        writer |> write("; ")
                    writer |> write("arg_{decorate_name(inp.name)}:{reg_type(inp._type)}")
                for outp in pins.outputs
                    eidx ++
                    if eidx != 1
                        writer |> write("; ")
                    writer |> write("var arg_{decorate_name(outp.name)}:{reg_type(outp._type)}")
                    if outp._type!=TYPE_SURFACE
                        writer |> write("&");
                writer |> write(")\n")
                var inscope aevl <- produce_eval(act)
                for t in aevl
                    writer |> write("{t}\n")
                writer |> write("\n")
        writer |> write("[export]\n")
        writer |> write("def main\n")
        var inscope evl <- produce_eval()
        for t in evl
            writer |> write("{t}\n")
        writer |> write("\n")
    return st
