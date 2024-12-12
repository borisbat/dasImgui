options indenting = 4

// OLD das restrictions
options unsafe_table_lookup = false
options strict_smart_pointers = false
options relaxed_pointer_const = true


module instructions_model

require instructions public
require model
require preview
require instructions_ui
require produce
require math

require instructions_math public

require daslib/strings_boost

// actions

[instruction_node(name="Call action",category="Actions")]
class Instruction_CallAction : Instruction
    [[serialize]] fn : string
    def Instruction_CallAction
        pass
    def override pre_sync : void
        unsafe
            delete pins
        pins <- collect_action_pins(g_CurrentProject, fn)
    def override sync : void
        var new_pins <- collect_action_pins(g_CurrentProject, fn)
        for np in new_pins.inputs
            for p in pins.inputs
                if p.name==np.name && p._type==np._type
                    np.src = p.src
                    np.output = p.output
                    break
        unsafe
            delete pins
        pins <- new_pins
    def override edit ( mode:EditMode ) : void
        assert(owner!=null)
        Text("{owner.actions[fn]} : {fn}")
    def override produce ( var src_regs : array<int> ): array<string>
        var args <- [{for reg,inp in src_regs,pins.inputs; to_reg_any(reg,inp._type)}]
        for oreg in pins.outputs
            if oreg.reg != -1
                args |> push(to_reg(oreg.reg))  // always real register
        var astr = join(args, ",")
        return <- [{string
            "fn_{decorate_name(fn)}({astr})"
            // ;"preview({to_reg(pins.outputs[0].reg)},\"{name}\",\"{id}\",\"unexpected\")"
        }]

// action arguments

class Instruction_ActionArgumentAny : Instruction_Argument
    override flags = InstructionFlags HasEdit | InstructionFlags Argument | InstructionFlags Input
    override argument_name = "Arg"
    def Instruction_ActionArgumentAny(argt:string)
        argument_type = argt
        self->add_output("Out",argument_type)
    def override edit ( mode:EditMode ) : void
        NodeArgumentName(mode,id,"Argument name",argument_name,owner)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "{to_reg_any(pins.outputs[0].reg,argument_type)} = arg_{decorate_name(id)} // {argument_name}"
        }]

[instruction_node(name="Argument, scalar",category="Actions")]
class Instruction_ActionArgumentScalar : Instruction_ActionArgumentAny
    def Instruction_ActionArgumentScalar
        Instruction_ActionArgumentAny`Instruction_ActionArgumentAny(self,TYPE_SCALAR)

[instruction_node(name="Argument, vector2",category="Actions")]
class Instruction_ActionArgumentVector2 : Instruction_ActionArgumentAny
    def Instruction_ActionArgumentVector2
        Instruction_ActionArgumentAny`Instruction_ActionArgumentAny(self,TYPE_VECTOR2)

[instruction_node(name="Argument, vector3",category="Actions")]
class Instruction_ActionArgumentVector3 : Instruction_ActionArgumentAny
    def Instruction_ActionArgumentVector3
        Instruction_ActionArgumentAny`Instruction_ActionArgumentAny(self,TYPE_VECTOR3)

[instruction_node(name="Argument, vector4",category="Actions")]
class Instruction_ActionArgumentVector4 : Instruction_ActionArgumentAny
    def Instruction_ActionArgumentVector4
        Instruction_ActionArgumentAny`Instruction_ActionArgumentAny(self,TYPE_VECTOR4)

[instruction_node(name="Argument, surface",category="Actions")]
class Instruction_ActionArgumentSurface : Instruction_ActionArgumentAny
    def Instruction_ActionArgumentSurface
        Instruction_ActionArgumentAny`Instruction_ActionArgumentAny(self,TYPE_SURFACE)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},arg_{decorate_name(id)}.size) // {to_reg_any(pins.outputs[0].reg,argument_type)} = {argument_name}";
            "surface_gen_copy({to_reg(pins.outputs[0].reg)},arg_{decorate_name(id)})"
        }]

// action results

class Instruction_ActionResultAny : Instruction_Argument
    override flags = InstructionFlags HasEdit | InstructionFlags Argument | InstructionFlags Output
    override argument_name = "Res"
    def Instruction_ActionResultAny(argt:string)
        argument_type = argt
        self->add_input("In",argument_type)
    def override edit ( mode:EditMode ) : void
        NodeArgumentName(mode,id,"Result name",argument_name,owner)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "arg_{decorate_name(id)} = {to_reg_any(src_regs[0],argument_type)}"
        }]

[instruction_node(name="Result, scalar",category="Actions")]
class Instruction_ActionResultScalar : Instruction_ActionResultAny
    def Instruction_ActionResultScalar
        Instruction_ActionResultAny`Instruction_ActionResultAny(self,TYPE_SCALAR)

[instruction_node(name="Result, vector2",category="Actions")]
class Instruction_ActionResultVector2 : Instruction_ActionResultAny
    def Instruction_ActionResultVector2
        Instruction_ActionResultAny`Instruction_ActionResultAny(self,TYPE_VECTOR2)

[instruction_node(name="Result, vector3",category="Actions")]
class Instruction_ActionResultVector3 : Instruction_ActionResultAny
    def Instruction_ActionResultVector3
        Instruction_ActionResultAny`Instruction_ActionResultAny(self,TYPE_VECTOR3)

[instruction_node(name="Result, vector4",category="Actions")]
class Instruction_ActionResultVector4 : Instruction_ActionResultAny
    def Instruction_ActionResultVector4
        Instruction_ActionResultAny`Instruction_ActionResultAny(self,TYPE_VECTOR4)

[instruction_node(name="Result, surface",category="Actions")]
class Instruction_ActionResultSurface : Instruction_ActionResultAny
    preview : bool = false
    def Instruction_ActionResultSurface
        Instruction_ActionResultAny`Instruction_ActionResultAny(self,TYPE_SURFACE)
    def override edit ( mode:EditMode ): void
        Instruction_ActionResultAny`edit(self,mode)
        NodeCheckbox(mode,id,"preview",preview)
    def override produce ( var src_regs : array<int> ): array<string>
        var res <- [{string
            "create_surface(arg_{decorate_name(id)},{to_reg_any(src_regs[0],argument_type)}.size)";
            "surface_gen_copy(arg_{decorate_name(id)},{to_reg_any(src_regs[0],argument_type)})"
        }]
        if preview
            res |> push("preview(arg_{decorate_name(id)},\"{name}\",\"{id}\",\"unexpected\")")
        return <- res

// comment

[instruction_node(name="Comment",category="Miscellaneous")]
class Instruction_Comment : Instruction
    [[serialize]] comment : string = "Comment"
    override flags = InstructionFlags Comment | InstructionFlags HasEdit
    def Instruction_Comment
        pass
    def override edit ( mode:EditMode ): void
        NodeTextMultiline(mode,id,"comment",comment,256)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [[array<string>]]

// output

[instruction_node(name="Output surface",category="Surface operations")]
class Instruction_OutputSurface : Instruction
    override flags = InstructionFlags Output
    def Instruction_OutputSurface
        self->add_input("In",TYPE_SURFACE)
    def override edit ( mode:EditMode ): void
        pass
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "output({to_reg_surface(src_regs[0])},\"{name}\",\"{id}\",\"\")"
        }]

[instruction_node(name="Output Blinn-phong surface",category="Surface operations")]
class Instruction_OutputSurfacePBR : Instruction
    override flags = InstructionFlags Output | InstructionFlags HasEdit
    kDiff : float = 1.0
    kSpec : float = 2.0
    pSpec : float = 16.0
    def Instruction_OutputSurfacePBR
        self->add_input("Diffuse",TYPE_SURFACE)
        self->add_input("Specular",TYPE_SURFACE)
        self->add_input("Normal",TYPE_SURFACE)
    def override edit ( mode:EditMode ): void
        NodeDragFloat(mode,id,"kDiff",kDiff)
        NodeDragFloat(mode,id,"kSpec",kSpec)
        NodeDragFloat(mode,id,"pSpec",pSpec)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "output_blinn_phong({to_reg_surface(src_regs[0])},{to_reg_surface(src_regs[1])},{to_reg_surface(src_regs[2])},{kDiff},{kSpec},{pSpec},\"{name}\",\"{id}\",\"\")"
        }]

// surface operations

[instruction_node(name="Solid color",category="Surface operations")]
class Instruction_SolidColor : Instruction
    [[serialize]] size : int2 = int2(4,4)
    [[serialize]] color : float4 = float4(.5,.5,.5,1.)
    def Instruction_SolidColor
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ): void
        NodeInputInt2(mode,id,"size",size)
        NodeColorEditor4(mode,id,"color",color)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_produce(size)})";
            "surface_gen_solid_color({to_reg(pins.outputs[0].reg)},{to_produce(color)})"
        }]

[instruction_node(name="Image file",category="Surface operations")]
class Instruction_ImageFile : Instruction
    [[serialize]] fileName : string = ""
    def Instruction_ImageFile
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ): void
        NodeFileName(mode,id,"file",fileName)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "surface_gen_image({to_reg(pins.outputs[0].reg)},\"{escape(fileName)}\")"
        }]

[instruction_node(name="Blur",category="Surface operations")]
class Instruction_Blur : Instruction
    [[serialize]] sigma : float = 2.0
    def Instruction_Blur
        self->add_input("Inp",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        NodeDragFloat(mode,id,"sigma",sigma)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])}.size)";
            "surface_gen_blur({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])},{sigma})"
        }]

[instruction_node(name="Sobel",category="Surface operations")]
class Instruction_Sobel : Instruction
    def Instruction_Sobel
        self->add_input("Inp",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        pass
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])}.size)";
            "surface_gen_sobel({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])})"
        }]

[instruction_node(name="Greyscale",category="Surface operations")]
class Instruction_Greyscale : Instruction
    def Instruction_Greyscale
        self->add_input("Inp",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        pass
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])}.size)";
            "surface_gen_greyscale({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])})"
        }]

[instruction_node(name="Gradient",category="Surface operations")]
class Instruction_Gradient : Instruction
    [[serialize]] size : int2 = int2(256,256)
    [[serialize]] top_left : float4 = float4(1.,0.,0.,1.)
    [[serialize]] top_right : float4 = float4(0.,1.,0.,1.)
    [[serialize]] bottom_left : float4 = float4(0.,0.,1.,1.)
    [[serialize]] bottom_right : float4 = float4(0.5,0.5,0.5,1.)
    def Instruction_Gradient
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        NodeInputInt2(mode,id,"size",size)
        NodeColorEditor4(mode,id,"top-left",top_left)
        NodeColorEditor4(mode,id,"top-right",top_right)
        NodeColorEditor4(mode,id,"bottom-left",bottom_left)
        NodeColorEditor4(mode,id,"bottom-right",bottom_right)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_produce(size)})";
            "surface_gen_gradient({to_reg(pins.outputs[0].reg)},{to_produce(top_left)},{to_produce(top_right)},{to_produce(bottom_left)},{to_produce(bottom_right)})"
        }]

enum BlendOp
    Add
    Multiply
    Crossfade

[instruction_node(name="Blend",category="Surface operations")]
class Instruction_Blend : Instruction
    [[serialize]] op  : BlendOp = BlendOp Add
    def Instruction_Blend
        self->add_input("Src",TYPE_SURFACE)
        self->add_input("Dst",TYPE_SURFACE)
        self->add_input("Factor",TYPE_SCALAR)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        NodeEditEnumeration(mode,id,"Operation",op)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},max({to_reg_surface(src_regs[0])}.size,{to_reg_surface(src_regs[1])}.size))";
            "surface_blend_{op}({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])},{to_reg_surface(src_regs[1])},{to_reg(src_regs[2],"0.5f")})"
        }]

[instruction_node(name="Texture Crossfade",category="Surface operations")]
class Instruction_TextureCrossfade : Instruction
    def Instruction_TextureCrossfade
        self->add_input("Src",TYPE_SURFACE)
        self->add_input("Dst",TYPE_SURFACE)
        self->add_input("Factor",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        pass
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},max(max({to_reg_surface(src_regs[0])}.size,{to_reg_surface(src_regs[1])}.size),{to_reg_surface(src_regs[2])}.size))";
            "surface_blend_tex_Crossfade({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])},{to_reg_surface(src_regs[1])},{to_reg_surface(src_regs[2])})"
        }]

[instruction_node(name="Compose",category="Surface operations")]
class Instruction_Compose : Instruction
    [[serialize]] size : int2 = int2(256,256)
    [[serialize]] applySize : bool = false
    [[serialize]] aa : bool = false
    [[serialize]] offset : float2 = float2(0.,0.)
    [[serialize]] scale  : float2 = float2(1.,1.)
    [[serialize]] angle  : float  = 0.
    def Instruction_Compose
        self->add_input("Src",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        NodeInputInt2(mode,id,"size",size)
        NodeCheckbox(mode,id,"apply size",applySize)
        NodeCheckbox(mode,id,"antialias",aa)
        NodeDragFloat2(mode,id,"offset",offset)
        NodeDragFloat2(mode,id,"sclae",scale)
        NodeDragFloat (mode,id,"angle",angle)
    def override produce ( var src_regs : array<int> ): array<string>
        let rad = angle * PI / 180.
        let aps = applySize ? "{to_produce(size)}" : "{to_reg_surface(src_regs[0])}.size"
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{aps})";
            "surface_gen_compose({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])},float2({offset.x},{offset.y}),float2({scale.x},{scale.y}),{angle},{aa})"
        }]

[instruction_node(name="Brightness and contrast",category="Surface operations")]
class Instruction_BrightnessContrast : Instruction
    [[serialize]] brightness  : float  = 0.
    [[serialize]] contrast    : float  = 1.
    def Instruction_BrightnessContrast
        self->add_input("Src",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        NodeDragFloat (mode,id,"brightness",brightness)
        NodeDragFloat (mode,id,"contrast",contrast)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])}.size)";
            "surface_gen_brightness_contrast({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])},{brightness},{contrast})"
        }]

[instruction_node(name="Inverse",category="Surface operations")]
class Instruction_Inverse : Instruction
    def Instruction_Inverse
        self->add_input("Src",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        pass
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])}.size)";
            "surface_gen_inverse({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])})"
        }]

[instruction_node(name="Height map to normal map",category="Surface operations")]
class Instruction_H2N : Instruction
    [[serialize]] scale : float = 2.0
    def Instruction_H2N
        self->add_input("Src",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        NodeDragFloat (mode,id,"scale",scale)
    def override produce ( var src_regs : array<int> ): array<string>
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])}.size)";
            "surface_gen_height_to_normal({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])},{scale})"
        }]

[instruction_node(name="Copy or resize",category="Actions")]
class Instruction_Resize : Instruction
    [[serialize]] size : int2 = int2(256,256)
    [[serialize]] applySize : bool = false
    [[serialize]] factorMul : int2 = int2(1)
    [[serialize]] factorDiv : int2 = int2(1)
    def Instruction_Resize
        self->add_input("Src",TYPE_SURFACE)
        self->add_output("Out",TYPE_SURFACE)
    def override edit ( mode:EditMode ) : void
        if applySize
            Text("SIZE: {size}")
        else
            let fmul = max(factorMul,int2(1))
            let fdiv = max(factorDiv,int2(1))
            Text("SIZE * {fmul} / {fdiv}")
        NodeInputInt2(mode,id,"size",size)
        NodeCheckbox(mode,id,"apply size",applySize)
        NodeInputInt2(mode,id,"multiplier",factorMul)
        NodeInputInt2(mode,id,"divider",factorDiv)
    def override produce ( var src_regs : array<int> ): array<string>
        let fmul = max(factorMul,int2(1))
        let fdiv = max(factorDiv,int2(1))
        let sz = applySize ? "int2({size.x},{size.y})" : "{to_reg_surface(src_regs[0])}.size*int2({fmul.x},{fmul.y})/int2({fdiv.x},{fdiv.y})"
        return <- [{string
            "create_surface({to_reg(pins.outputs[0].reg)},{sz})";
            "surface_gen_copy({to_reg(pins.outputs[0].reg)},{to_reg_surface(src_regs[0])})"
        }]


