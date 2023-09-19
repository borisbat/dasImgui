options indenting = 4

module preview private

require glfw/glfw_boost
require daslib/safe_addr
require daslib/static_let
require daslib/math_boost

require opengl/opengl_boost
require opengl/opengl_ttf
require opengl/opengl_gen

require instructions public
require model_eval
require model
require math
require strings

enum PreviewMode
    Sphere
    CubeSphere
    Cube
    Cylinder

var public g_PreviewTexture : array<Material>
var public g_LivePreview = true
var public g_AlwaysLitPreview = true
var public g_PreviewLabels = true
var public g_PreviewMode = PreviewMode Sphere

def make_checkerboard
    var surf = Surface(16,16)
    surf.tex = gen_image_checkerboard(16,16, 0xff404040 , 0xff808080) |> create_texture
    glBindTexture(GL_TEXTURE_2D, surf.tex)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glBindTexture(GL_TEXTURE_2D, 0u)
    return surf

def public clear_preview
    delete g_PreviewTexture

var public g_PreviewUpdater : function<():void>

def public update_preview
    if g_LivePreview
        clear_preview()
        if g_PreviewUpdater != null
            invoke(g_PreviewUpdater)

var [[in, location=0]] v_position : float3
var [[in, location=1]] v_normal   : float3
var [[in, location=2]] v_texcoord : float2
var [[uniform]] v_model : float4x4
var [[uniform]] v_view : float4x4
var [[uniform]] v_projection : float4x4
var [[inout]] f_texcoord : float2
var [[inout]] f_normal : float3
var [[inout]] f_position : float3
var [[uniform, stage=0]] f_tex : sampler2D
var [[uniform, stage=1]] f_spec : sampler2D
var [[uniform, stage=2]] f_norm : sampler2D
var [[uniform]] f_kD : float
var [[uniform]] f_kS : float
var [[uniform]] f_pS : float
var [[out]] f_FragColor : float4

[fragment_program]
def ps_preview_main
    f_FragColor = texture(f_tex,f_texcoord)

[vertex_program]
def vs_preview_pbr
    f_texcoord = v_texcoord
    f_normal = normalize ( float3x3(v_model) * v_normal )
    let tpos = v_model * float4(v_position, 1.0)
    f_position = tpos.xyz
    gl_Position = v_projection * v_view * tpos

def get_normal
    let dp1  = dFdx(f_position)
    let dp2  = dFdy(f_position)
    let duv1 = dFdx(f_texcoord)
    let duv2 = dFdy(f_texcoord)
	// solve the linear system
    let N = normalize(f_normal)
  	let dp2perp = cross(dp2, N);
  	let dp1perp = cross(N, dp1);
  	let T = normalize(dp2perp * duv1.x + dp1perp * duv2.x);
  	let B = normalize(dp2perp * duv1.y + dp1perp * duv2.y);
    // let TBN = mat3(T, B, N)
    var TBN : float3x3
    TBN[0] = T
    TBN[1] = B
    TBN[2] = N
	return normalize(TBN * (texture(f_norm, f_texcoord).xyz * 2.0 - float3(1.0)))

[fragment_program]
def ps_preview_pbr
    let light_dir = normalize(float3(-1,-2,-3))
    let camera_dir = normalize(f_position)
    let normal = get_normal()
    // blinn-phong
    let k = -dot(light_dir,normal)
    let diffuse = float3(saturate(k)) * f_kD
    let refl = normalize ( reflect(camera_dir,normal) )
    let kS = saturate(dot(-light_dir,refl))
    let specular = float3(pow(kS,f_pS)*f_kS)
    f_FragColor.xyz =  (
        texture(f_tex,  f_texcoord).xyz * diffuse +
        texture(f_spec, f_texcoord).xyz * specular
    )
    f_FragColor.w = 1.

[fragment_program]
def ps_preview_lit
    let light_dir = normalize(float3(-1,-2,-3))
    let camera_dir = normalize(f_position)
    let normal = normalize(f_normal)
    // blinn-phong
    let k = -dot(light_dir,normal)
    let diffuse = float3(saturate(k)) * f_kD
    let refl = normalize ( reflect(camera_dir,normal) )
    let kS = saturate(dot(-light_dir,refl))
    let specular = float3(pow(kS,f_pS)*f_kS)
    f_FragColor.xyz = texture(f_tex,  f_texcoord).xyz *  diffuse + specular
    f_FragColor.w = 1.

var program, program_pbr, program_lit : uint

var ttf : bool = false
var font : Font
var cube, sphere, sphere_cuv, cylinder : OpenGLGeometryFragment

def public create_preview_objects
    program = create_shader_program(@@vs_preview_pbr,@@ps_preview_main)
    program_pbr = create_shader_program(@@vs_preview_pbr,@@ps_preview_pbr)
    program_lit = create_shader_program(@@vs_preview_pbr,@@ps_preview_lit)
    font <- load_ttf([
      fname = "droidsansmono.ttf",
      path1 = "{get_das_root()}/modules/dasBGFX/bgfx/bgfx/examples/runtime/font",
      path2 = "{get_das_root()}/examples/media",
      canfail = true
    ])
    cube <- gen_cube() |> create_geometry_fragment
    sphere <- gen_sphere(32,16,false) |> create_geometry_fragment
    sphere_cuv <- gen_sphere(32,16,true) |> create_geometry_fragment
    cylinder <- gen_cylinder(GenDirection xz, 32) |> create_geometry_fragment

def public draw_preview ( display_w, display_h : int )
    static_let <|
        var rot_cube = 0.
        var rot_tri = 0.
    if length(g_PreviewTexture)==0
        g_PreviewTexture |> emplace <| [[Material
            surf=make_checkerboard(),
            name="Checkerboard",
            id="nothing",
            outp="nothing"]]
    rot_cube += 1.0
    if rot_cube > 360.
        rot_cube -= 360.
    rot_tri += 0.5
    if rot_tri > 360.
        rot_tri -= 360.
    let total = length(g_PreviewTexture)
    let sqX = max(1,int(ceil(sqrt(float(total)))))
    let sqY = max(1,(total+sqX-1)/sqX)
    // print("sqX={sqX} sqY={sqY} total={total}\n")
    assert(sqX * sqY >= total)
    let stepX = 2.2
    let stepY = 2.2
    let halfX = -stepX*float(max(sqX-1,0))*0.5
    let halfY = -stepY*float(max(sqY-1,0))*0.5
    var index = 0
    identity(v_view)
    for y in range(sqY)
        for x in range(sqX)
            let rot1 = quat_from_unit_vec_ang(normalize(float3(1.,0.,0.)), radians(rot_tri * 0.25))
            let rot2 = quat_from_unit_vec_ang(normalize(float3(0.,1.,0.)), radians(rot_cube))
            let rot = quat_mul(rot1, rot2)
            v_model = compose(
                    float4(float(x)*stepX+halfX, float(y)*stepY+halfY, -2. - float(sqX-1)*2., 0.0),
                    rot,
                    float4(g_PreviewMode==PreviewMode Cube ? 0.7 : 1.))
            let aspect = display_h>0 ? float(display_w)/float(display_h) : 1.0
            v_projection = perspective_rh( radians(45.0f), aspect, 0.1f, 100.0f)
            glEnable(GL_DEPTH_TEST)
            glDepthFunc(GL_LEQUAL)
            glEnable(GL_CULL_FACE)
            glCullFace(GL_BACK)
            if g_PreviewTexture[index].norm.tex!=0u && g_PreviewTexture[index].spec.tex!=0u
                f_tex := g_PreviewTexture[index].surf.tex
                f_spec := g_PreviewTexture[index].spec.tex
                f_norm := g_PreviewTexture[index].norm.tex
                f_kD = g_PreviewTexture[index].opt?["kDiff"] ?? 1.0
                f_kS = g_PreviewTexture[index].opt?["kSpec"] ?? 1.0
                f_pS = g_PreviewTexture[index].opt?["pSpec"] ?? 1.0
                glUseProgram(program_pbr)
                vs_preview_pbr_bind_uniform(program_pbr)
                ps_preview_pbr_bind_uniform(program_pbr)
            else
                f_tex := g_PreviewTexture[index].surf.tex
                let prog = g_AlwaysLitPreview ? program_lit : program
                f_kD = 1.0
                f_kS = 1.0
                f_pS = 24.0
                glUseProgram(prog)
                vs_preview_pbr_bind_uniform(prog)
                if g_AlwaysLitPreview
                    ps_preview_lit_bind_uniform(prog)
                else
                    ps_preview_main_bind_uniform(prog)
            if g_PreviewMode==PreviewMode Cube
                cube |> draw_geometry_fragment()
            elif g_PreviewMode==PreviewMode Sphere
                sphere |> draw_geometry_fragment()
            elif g_PreviewMode==PreviewMode CubeSphere
                sphere_cuv |> draw_geometry_fragment()
            elif g_PreviewMode==PreviewMode Cylinder
                cylinder |> draw_geometry_fragment()
            glDisable(GL_CULL_FACE)
            glDisable(GL_DEPTH_TEST)
            if g_PreviewLabels
                var hw_text <- font |> create_quads(g_PreviewTexture[index].name)
                let qmodel = quads_view(hw_text, float2(1.0/300.0))
                let model = translation(float3(float(x)*stepX+halfX, (float(y)+0.45)*stepY+halfY, -2.2 - float(sqX-1)*2.)) * qmodel
                let mvp = v_projection * v_view * model
                font |> draw_quads(hw_text, mvp)
                delete hw_text
            bind_ffp()
            index ++
            if index==total
                break

