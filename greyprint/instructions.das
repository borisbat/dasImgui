options gen2
options indenting = 4


// OLD das restrictions
options unsafe_table_lookup = false
options strict_smart_pointers = false
options relaxed_pointer_const = true


module instructions shared

require rtti
require imgui
require uriparser
require strings
require daslib/json_boost public
require daslib/safe_addr
require daslib/ast_boost
require daslib/static_let
require daslib/strings_boost
require opengl/opengl_boost

let DEBUG_TEXTURE_LIFETIME = false

// surface

struct Surface {
    size : int2
    tex  : uint
    fbo  : uint
}

def Surface(w, h : int) {
    return <- Surface(size = int2(w, h))
}

def finalize(var self : Surface) {
    if (self.tex != 0u) {
        if (DEBUG_TEXTURE_LIFETIME) {
            print(" ! glDeleteTextures {self.tex}\n")
        }
        glDeleteTextures(1, unsafe(addr(self.tex)))
        self.tex = 0u
    }
    if (self.fbo != 0u) {
        glDeleteFramebuffers(1, unsafe(addr(self.fbo)))
        self.fbo = 0u
    }
}

struct Material {
    surf   : Surface
    spec   : Surface
    norm   : Surface
    name   : string
    id     : string
    outp   : string
    opt    : table<string; float>
}

// instructions

struct Connection {
    name    : string
    text    : string
    _type   : string
}

def get_display_name(self : Connection) {
    return empty(self.text) ? self.name : self.text
}

struct Input : Connection {
    @do_not_delete src : Instruction?
    output : string
}

def connect(var inp : Input; src : Instruction?; outp : string) {
    inp.src = src
    inp.output = outp
}

struct Output : Connection {
    preview : bool
    reg     : int
    tex     : void?
}

let TYPE_SURFACE = "surface"
let TYPE_SCALAR = "scalar"
let TYPE_VECTOR2 = "vector2"
let TYPE_VECTOR3 = "vector3"
let TYPE_VECTOR4 = "vector4"

let CATEGORY_UNCATEGORIZED = "Uncategorized"

enum EditMode {
    Sidebar         // in the side menu
    Embedded        // in the node
}

bitfield InstructionFlags {
    Output
    HasEdit
    Comment
    Input
    Argument
}

struct Pins {
    inputs : array<Input>
    outputs : array<Output>
}

class Instruction {
    id : string                             // unique ID of instruction (expecting GUID)
    name : string                           // user readable name. can be duplicate
    category : string                       // instruction category
    action : string
    at : float2                             // position in the node editor
    extents : float2 = float2(256., 256.)   // size in the node editor (for relevant nodes)
    flags : InstructionFlags = InstructionFlags.HasEdit
    firstFrame : bool = true
    hasPosition : bool = false
    select : bool = false
    navigate : bool = false
    pins : Pins
    tex : void?
    @do_not_delete owner : Project?
    def abstract edit(mode : EditMode) : void
    def abstract save(var node : table<string; JsonValue?>) : void
    def abstract load(var node : table<string; JsonValue?>) : void
    def abstract produce(var src_regs : array<int>) : array<string>
    def sync : void {
        pass
    }
    def pre_sync : void {
        pass
    }
    def add_input(iname, itype : string) {
        pins.inputs |> push(Input(name = iname, _type = itype))
    }
    def add_output(iname, itype : string) {
        pins.outputs |> push(Output(name = iname, _type = itype))
    }
    def input_index(iname : string) : int {
        return pins.inputs |> find_index_if <| $(val) {
            return val.name == iname
        }
    }
    def output_index(iname : string) : int {
        return pins.outputs |> find_index_if <| $(val) {
            return val.name == iname
        }
    }
    def JV {
        var tname = class_info(self).name
        var inode <- {
            "id" => JV(id),
            "name" => JV(name),
            "action" => JV(action),
            "rtti" => JV(tname),
            "at" => JV(at),
            "extents" => JV(extents)
        }
        self->save(inode)
        return JV(inode)
    }
    def from_JV(var pnode : JsonValue?) {
        var node & = unsafe(pnode.value as _object)
        id = node["id"].value as _string
        name = node["name"].value as _string
        action = node["action"].value as _string
        at = from_JV(node["at"], type<float2>)
        extents = from_JV(node["extents"], type<float2>)
        self->load(node)
    }
}

def find_input(var inst : Instruction?; iname : string; blk : block<(var inp : Input?#) : void>) : void {
    for (i in inst.pins.inputs) {
        if (i.name == iname) {
            invoke(blk, safe_addr(i))
            return
        }
    }
    unsafe {
        invoke(blk, reinterpret<Input?#> null)
    }
}


def find_output(var inst : Instruction?; iname : string implicit; blk : block<(var inp : Output?#) : void>) : void {
    for (i in inst.pins.outputs) {
        if (i.name == iname) {
            invoke(blk, safe_addr(i))
            return
        }
    }
    unsafe {
        invoke(blk, reinterpret<Output?#> null)
    }
}

class Instruction_Argument : Instruction {
    override flags = InstructionFlags.HasEdit | InstructionFlags.Argument
    @serialize argument_name : string
    argument_type : string
}

def decorate_name(an : string) {
    static_let <| $() {
        let repl <- {
            ' ' => "_",
            ',' => "_comma_",
            '*' => "_times_",
            '+' => "_plus_",
            '-' => "_dash_"
        }
    }
    let st = build_string() <| $(var writer) {
        for (ch in an) {
            if (repl |> key_exists(ch)) {
                writer |> write(repl?[ch] ?? "")
            } else {
                writer |> write_char(ch)
            }
        }
    }
    return st
}

// project

def generate_new_id() {
    return uriparser::make_new_guid()
}

class Project {
    instructions : array<Instruction?>
    lookup : table<string; Instruction?>
    actions : table<string; string>
    def clear {
        delete actions
        delete instructions
        clear(lookup)
    }
    def finalize {
        self->clear()
    }
    def find_instruction(id : string implicit) : Instruction? {
        return lookup?[id] ?? default<Instruction?>
    }
    def add_insturction(var i : Instruction?) {
        unsafe {
            i.owner = addr(self)
        }
        instructions |> push(i)
        lookup[i.id] = i
    }
    def add_new_insturction(var i : Instruction?) {
        i.id = generate_new_id()
        self->add_insturction(i)
    }
    def delete_instruction(var dinst : Instruction?) {
        var idx = -1
        for (i, index in instructions, count()) {
            if (i == dinst) {
                idx = index
            }
            for (inp in i.pins.inputs) {
                if (inp.src == dinst) {
                    inp.src = null
                }
            }
        }
        assert(idx != -1)
        instructions |> erase(idx)
        lookup |> erase(dinst.id)
        unsafe {
            delete dinst
        }
    }
    def save_link(var inst : Instruction?; inp : Input) : JsonValue? {
        var lnk <- {
            "input_id"    => JV(inst.id),
            "input_name"  => JV(inp.name),
            "output_id"   => JV(inp.src.id),
            "output_name" => JV(inp.output)
        }
        return JV(lnk)
    }
    def save_with_filter(export_actions : bool; filter : block<(inst : Instruction?) : bool>) : JsonValue? {
        var nodes : array<JsonValue?>
        for (inst in instructions) {
            if (invoke(filter, inst)) {
                nodes |> push(inst->JV())
            }
        }
        var links : array<JsonValue?>
        for (inst in instructions) {
            if (invoke(filter, inst)) {
                for (inp in inst.pins.inputs) {
                    if (inp.src != null) {
                        if (invoke(filter, inp.src)) {
                            links |> push(self->save_link(inst, inp))
                        }
                    }
                }
            }
        }
        var root <- {
            "nodes" => JV(nodes),
            "links" => JV(links)
        }
        var act <- export_actions ? JV(actions) : JV(table<string; string>())
        root["actions"] <- act
        unsafe {
            delete act
        }
        return JV(root)
    }
    def save : JsonValue ? {
        return self->save_with_filter(true) <| $(inst : Instruction?) {
            return true
        }
    }
    def load_instruction(var pnode : JsonValue?) {
        var node & = unsafe(pnode.value as _object)
        let ntype = node["rtti"].value as _string
        var inst = make_instruction(ntype)
        (*inst)->from_JV(pnode)
        inst.hasPosition = true
        self->add_insturction(inst)
        return inst
    }
    def load_links(var rlinks : JsonValue?) : void {
        var links & = unsafe(rlinks.value as _array)
        for (plink in links) {
            var link & = unsafe(plink.value as _object)
            let input_id = link["input_id"].value as _string
            var inst = self->find_instruction(input_id)
            assert(inst != null)
            let input_name = link["input_name"].value as _string
            inst |> find_input(input_name) <| $(inp) {
                if (inp != null) {
                    inp.output = link["output_name"].value as _string
                    let output_id = link["output_id"].value as _string
                    inp.src = self->find_instruction(output_id)
                }
            }
        }
    }
    def load(var proot : JsonValue?) : void {
        if (proot == null) {
            return
        }
        var root & = unsafe(proot.value as _object)
        var nodes & = unsafe(root["nodes"].value as _array)
        for (pnode in nodes) {
            self->load_instruction(pnode)
        }
        self->pre_sync()
        self->load_links(root["links"])
        var acts & = unsafe(root["actions"].value as _object)
        delete actions
        for (aid, aname in keys(acts), values(acts)) {
            actions[aid] = aname as _string
        }
        self->sync()
    }
    def pre_sync : void {
        for (inst in instructions) {
            (*inst)->pre_sync()
        }
    }
    def sync : void {
        for (inst in instructions) {
            (*inst)->sync()
        }
    }
}

def find_loop(src, inst : Instruction?; var visited : table<Instruction?; bool>) {
    if (visited |> key_exists(inst)) {
        return false
    }
    visited[inst] = true
    for (inp in inst.pins.inputs) {
        if (inp.src != null) {
            if (inp.src == src) {
                return true
            }
            if (find_loop(src, inp.src, visited)) {
                return true
            }
        }
    }
    return false
}

def find_loop(proj : Project?) {
    for (inst in proj.instructions) {
        var visited : table<Instruction?; bool>
        if (find_loop(inst, inst, visited)) {
            return true
        }
    }
    return false
}

def clone_instruction(var inst : Instruction?) : Instruction? {
    var jvi = inst->JV()
    var newI = make_instruction((jvi as _object)["rtti"] as _string)
    (*newI)->from_JV(jvi)
    unsafe {
        delete jvi
    }
    return newI
}

def create_selection_project(var proj : Project?; selection : table<string; bool>) : Project? {
    var newProject = new Project()
    var i2ni : table<string; Instruction?>
    for (inst in proj.instructions) {
        if (selection |> key_exists(inst.id)) {
            var newI = clone_instruction(inst)
            (*newProject)->add_insturction(newI)
            i2ni[inst.id] = newI
        }
    }
    for (ninst in newProject.instructions) {
        var inst = (*proj)->find_instruction(ninst.id)
        for (inp, ninp in inst.pins.inputs, ninst.pins.inputs) {
            if (inp.src != null && selection |> key_exists(inp.src.id)) {
                assert(i2ni |> key_exists(inp.src.id))
                ninp.src = i2ni[inp.src.id]
                ninp.output = inp.output
            }
        }
    }
    i2ni |> clear()
    delete i2ni
    return newProject
}

def merge_project(var proj, sel : Project?; offset : float2; action : string) {
    var i2ni : table<string; Instruction?>
    for (inst in sel.instructions) {
        var ninst = clone_instruction(inst)
        i2ni[inst.id] = ninst
        ninst.action = action
        ninst.at += offset
        ninst.firstFrame = true
        ninst.hasPosition = true
        ninst.select = true
        (*proj)->add_new_insturction(ninst)
    }
    for (inst in sel.instructions) {
        var ninst = i2ni[inst.id]
        for (inp, ninp in inst.pins.inputs, ninst.pins.inputs) {
            if (inp.src != null) {
                ninp.src = i2ni[inp.src.id]
                ninp.output = inp.output
            }
        }
    }
    i2ni |> clear()
    delete i2ni
}

def make_unique_action_name {
    return "Action {uriparser::make_new_guid()}"
}

def collect_action_pins(var proj : Project?; action : string) {
    var pins : Pins
    var input_index = 1
    var output_index = 1
    for (inst in proj.instructions) {
        if (inst.action == action && inst.flags.Argument) {
            unsafe {
                let arg_inst = upcast<Instruction_Argument?> inst
                if (inst.flags.Input) {
                    pins.inputs |> push <| Input(
                        name = arg_inst.id,
                        text = arg_inst.argument_name,
                        _type = arg_inst.argument_type
                    )
                }
                if (inst.flags.Output) {
                    pins.outputs |> push <| Output(
                        name = arg_inst.id,
                        text = arg_inst.argument_name,
                        _type = arg_inst.argument_type
                    )
                }
            }
        }
    }
    return <- pins
}

var g_CurrentProject : Project?

// factory

struct InstructionCategory {
    name : string
    category : string
    tname : string
    main_in : string
    main_out : string
}

var private g_instructionFactory : table < string; lambda<() : Instruction?> >

var g_instructionsByCategory : array<InstructionCategory>

[unused_argument(it_type)]
def make_instruction_factory(it_name, it_category : string; it_type : auto(InstType) -const) {
    let tname = typeinfo undecorated_typename(type<InstType>)
    var factory <- @() : Instruction? {
        var inst = new InstType()
        inst.name = it_name
        inst.category = it_category
        return inst
    }
    var dummy = invoke(factory)
    g_instructionFactory[tname] <- factory
    var main_in  = (length(dummy.pins.inputs) > 0) ? dummy.pins.inputs[0]._type : ""
    var main_out = (length(dummy.pins.outputs) > 0) ? dummy.pins.outputs[0]._type : ""
//  note: this causes crash on linux, todo: run with asan
//    unsafe
//        delete dummy
    g_instructionsByCategory |> push(InstructionCategory(
        name = it_name,
        category = it_category,
        tname = tname,
        main_in = main_in,
        main_out = main_out
    ))
}

def make_instruction(it_type : string implicit) {
    if (g_instructionFactory |> key_exists(it_type)) {
        return invoke(g_instructionFactory[it_type])
    } else {
        print("available types are {g_instructionFactory}\n")
        panic("making unknown instruction type {it_type}")
        return null
    }
}

def seal_instruction_factory {
    g_instructionsByCategory |> sort <| $(a, b) {
        if (a.category != b.category) {
            return a.category < b.category
        } else {
            return a.name < b.name
        }
    }
}

def generate_node_init(name, category : string; var str : StructurePtr) {
    let fnname = "init`instruction`{str.name}"
    var inscope fn <- compiling_module() |> find_unique_function(fnname)
    if (fn == null) {
        fn <- new Function(at = str.at, atDecl = str.at, name := fnname)
        fn.flags |= FunctionFlags.generated
        fn.flags |= FunctionFlags.init
        fn.result <- new TypeDecl(baseType = Type.autoinfer, at = str.at)
        var blk <- new ExprBlock(at = str.at)
        var cmt <- new TypeDecl(at = str.at, baseType = Type.tStructure, structType = get_ptr(str))
        var cmi <- new ExprCall(at = str.at, name := "make_instruction_factory")
        cmi.arguments |> emplace_new() <| new ExprConstString(at = str.at, value := name)
        cmi.arguments |> emplace_new() <| new ExprConstString(at = str.at, value := category)
        cmi.arguments |> emplace_new() <| new ExprTypeDecl(at = str.at, typeexpr <- cmt)
        blk.list |> emplace(cmi)
        fn.body <- blk
        return compiling_module() |> add_function(fn)
    }
    return true
}

// def {name} ( slef:{str._type}; var node:table<string;JsonValue> )
def generate_serialize(name : string; var str : StructurePtr) {
    var fn <- new Function(at = str.at, atDecl = str.at, name := name)
    fn.flags |= FunctionFlags.generated
    fn.result <- new TypeDecl(baseType = Type.autoinfer, at = str.at)
    fn.arguments |> emplace_new() <| new Variable(at = str.at,
        name := "self",
        _type <- new TypeDecl(at = str.at,
            baseType = Type.tStructure,
            structType = get_ptr(str)
        )
    )
    fn.arguments |> emplace_new() <| new  Variable(at = str.at,
        name := "node",
        _type <- typeinfo ast_typedecl(type<table<string; json::JsonValue?> -const>)
    )
    return <- fn
}

// def override save ( var node:table<string;json:JsonValue?> )
def generate_node_save(var str : StructurePtr) {
    let name = "{str.name}`save"
    var inscope fn <- compiling_module() |> find_unique_function(name)
    if (fn == null) {
        move_new(fn, generate_serialize(name, str))
        var blk <- new ExprBlock(at = str.at)
        for (fld in str.fields) {
            for (ann in fld.annotation) {
                if (ann.name == "serialize") {
                    // node["{fld.name}"] = JV(self.{fld.name})
                    var cll <- new ExprCall(at = str.at, name := "JV")
                    cll.arguments |> emplace_new() <| new ExprField(at = str.at,
                        name := fld.name,
                        value <- new ExprVar(at = str.at, name := "self")
                    )
                    var cpy <- new ExprCopy(at = str.at,
                        left <- new ExprAt(at = str.at,
                            subexpr <- new ExprVar(at = str.at, name := "node"),
                            index <- new ExprConstString(at = str.at, value := fld.name)
                        ),
                        right <- cll
                    )
                    blk.list |> emplace(cpy)
                    break
                }
            }
        }
        fn.body <- blk
        if (!(compiling_module() |> add_function(fn))) {
            return false
        }
        override_method(str, "save", "_::{name}")
    }
    return true
}

// def override load ( var node:table<string;json:JsonValue?> )
def generate_node_load(var str : StructurePtr) {
    let name = "{str.name}`load"
    var inscope fn <- compiling_module() |> find_unique_function(name)
    if (fn == null) {
        move_new(fn, generate_serialize(name, str))
        var blk <- new ExprBlock(at = str.at)
        for (fld in str.fields) {
            for (ann in fld.annotation) {
                if (ann.name == "serialize") {
                    // self.{fld.name} = from_JV(node["{fld.name}"],type<fld.type>)
                    var cll <- new ExprCall(at = str.at, name := "from_JV")
                    cll.arguments |> emplace_new() <| new ExprAt(at = str.at,
                        subexpr <- new ExprVar(at = str.at, name := "node"),
                        index <- new ExprConstString(at = str.at, value := fld.name)
                    )
                    cll.arguments |> emplace_new() <| new ExprTypeDecl(at = str.at,
                        typeexpr <- clone_type(fld._type)
                    )
                    var cpy <- new ExprCopy(at = str.at,
                        left <- new ExprField(at = str.at,
                            name := fld.name,
                            value <- new ExprVar(at = str.at, name := "self")
                        ),
                        right <- cll
                    )
                    blk.list |> emplace(cpy)
                    break
                }
            }
        }
        fn.body <- blk
        if (!(compiling_module() |> add_function(fn))) {
            return false
        }
        override_method(str, "load", "_::{name}")
    }
    return true
}

// add instruction type registration function
//  make_instruction_factory("Solid color", CATEGORY_SURFACE_OPERATIONS, type<Instruction_SolidColor>)
[structure_macro(name="instruction_node")]
class InstructionNodeStructureAnnotation : AstStructureAnnotation {
    def override apply(var str : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        // get name and category
        var category = CATEGORY_UNCATEGORIZED
        var name = "{str.name}"
        for (arg in args) {
            let val = get_annotation_argument_value(arg)
            if (!(val is tString)) {
                errors := "invalid argument {arg.name}"
                return false
            }
            let valName = "{arg.name}"
            let valValue = "{val as tString}"
            if (valName == "name") {
                name = valValue
            } elif (valName == "category") {
                category = valValue
            } else {
                errors := "invalid argument {arg.name}"
                return false
            }
        }
        if (!generate_node_init(name, category, str)) {
            errors := "can't generate node init"
            return false
        }
        if (!generate_node_save(str)) {
            errors := "can't generate node save"
            return false
        }
        if (!generate_node_load(str)) {
            errors := "can't generate node load"
            return false
        }
        return true
    }
}
