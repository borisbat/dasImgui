options indenting = 4

module model shared private

require opengl/opengl_cache

require instructions public
require math

require daslib/safe_addr
require daslib/static_let
require daslib/unroll

require opengl/opengl_boost

var [[uniform]] f_grad_tl : float4
var [[uniform]] f_grad_tr : float4
var [[uniform]] f_grad_bl : float4
var [[uniform]] f_grad_br : float4
var [[uniform]] f_weights : float[9]
var [[uniform]] f_iweights_summ : float
var [[in, location=0]] v_position : float2
var [[in, location=1]] v_texcoord : float2
var [[inout]] f_texcoord : float2
var [[uniform, stage=0]] f_tex : sampler2D
var [[uniform, stage=1]] f_tex2 : sampler2D
var [[uniform, stage=2]] f_tex3 : sampler2D
var [[uniform]] f_blend_factor : float
var [[uniform]] v_tex_transform : float4x4
var [[uniform]] f_contrast : float
var [[uniform]] f_brightness : float
var [[uniform]] f_normal_size : float
var [[out]] f_FragColor : float4

[vertex_program]
def vs_any_effect
    f_texcoord = v_texcoord
    gl_Position = float4(v_position, 0.0, 1.0)

[vertex_program]
def vs_transform_effect
    f_texcoord = (v_tex_transform * float4(v_texcoord.x - 0.5, v_texcoord.y - 0.5, 0., 1.)).xy + float2(0.5)
    gl_Position = float4(v_position, 0.0, 1.0)

[fragment_program]
def ps_copy_aa_effect
    let base00  = texture(f_tex, f_texcoord)
    let baseNW  = textureOffset(f_tex, f_texcoord, int2(-1,-1)).xyz
    let baseNE  = textureOffset(f_tex, f_texcoord, int2( 1,-1)).xyz
    let baseSW  = textureOffset(f_tex, f_texcoord, int2(-1, 1)).xyz
    let baseSE  = textureOffset(f_tex, f_texcoord, int2( 1, 1)).xyz
    let gray = normalize(float3(0.299, 0.587, 0.114))
    let lumaNw  = dot(baseNW, gray)
    let lumaNe  = dot(baseNE, gray)
    let lumaSw  = dot(baseSW, gray)
    let lumaSe  = dot(baseSE, gray)
    let dirSwMinusNe = lumaSw - lumaNe
    let dirSeMinusNw = lumaSe - lumaNw
    let dir = float2(dirSwMinusNe + dirSeMinusNw, dirSwMinusNe - dirSeMinusNw)
    let tsize = textureSize(f_tex,0)
    let isize = float2(1.) / float2(tsize.x,tsize.y)
    let rgbyN1 = texture(f_tex, f_texcoord - dir * isize).xyz
    let rgbyP1 = texture(f_tex, f_texcoord + dir * isize).xyz
    f_FragColor.xyz = base00.xyz*0.2 + rgbyN1*0.4 + rgbyP1*0.5
    f_FragColor.w = base00.w

[fragment_program]
def ps_copy_effect
    f_FragColor = texture(f_tex,f_texcoord)

[fragment_program]
def ps_height_to_normal_effect
    let size = float2(f_normal_size,0.0)
    let s01 = textureOffset(f_tex, f_texcoord, int2(-1, 0)).y
    let s21 = textureOffset(f_tex, f_texcoord, int2( 1, 0)).y
    let s10 = textureOffset(f_tex, f_texcoord, int2( 0,-1)).y
    let s12 = textureOffset(f_tex, f_texcoord, int2( 0, 1)).y
    let va  = normalize(float3(size.x,size.y,s21-s01))
    let vb  = normalize(float3(size.y,size.x,s12-s10))
    f_FragColor.xyz = cross(va,vb) * 0.5 + float3(0.5)
    f_FragColor.w = 1.

[fragment_program]
def ps_inverse_effect
    f_FragColor = saturate ( float4(1.) - texture(f_tex,f_texcoord) )

[fragment_program]
def ps_brightness_contrast_effect
    let color = texture(f_tex,f_texcoord)
    let colorContrasted = color.xyz * f_contrast
    f_FragColor.xyz = max ( colorContrasted + float3(f_brightness), float3(0.))
    f_FragColor.w = color.w

[fragment_program]
def ps_greyscale_effect
    let color = texture(f_tex,f_texcoord)
    let b = color.x * 0.299 + color.y * 0.587 + color.z * 0.114
    f_FragColor = float4(b, b, b, 1.0)

def make_kernel_3x3 ( var n : float4[9]; tex:sampler2D; coord:float2 )
	n[0] = textureOffset(tex, coord, int2(-1,-1))
	n[1] = textureOffset(tex, coord, int2( 0,-1))
	n[2] = textureOffset(tex, coord, int2( 1,-1))
	n[3] = textureOffset(tex, coord, int2(-1, 0))
	n[4] = textureOffset(tex, coord, int2( 0, 0))
	n[5] = textureOffset(tex, coord, int2( 1, 0))
	n[6] = textureOffset(tex, coord, int2(-1, 1))
	n[7] = textureOffset(tex, coord, int2( 0, 1))
	n[8] = textureOffset(tex, coord, int2( 1, 1))

[fragment_program]
def ps_sobel_effect
    var n : float4[9]
    make_kernel_3x3(n, f_tex, f_texcoord)
	let sobel_edge_h = n[2] + (2.0*n[5]) + n[8] - (n[0] + (2.0*n[3]) + n[6])
  	let sobel_edge_v = n[0] + (2.0*n[1]) + n[2] - (n[6] + (2.0*n[7]) + n[8])
	f_FragColor = sqrt((sobel_edge_h * sobel_edge_h) + (sobel_edge_v * sobel_edge_v))

def make_kernel_9x1 ( var n : float4[9]; tex:sampler2D; coord:float2 )
    unroll <|
        for i in range(9)
	        n[i] = textureOffset(tex, coord, int2(i-4,0))

def make_kernel_1x9 ( var n : float4[9]; tex:sampler2D; coord:float2 )
    unroll <|
        for i in range(9)
	        n[i] = textureOffset(tex, coord, int2(0,i-4))

def gaussian(x, sigma:float)
    return ( 1. / ( sqrt(2.*PI) * sigma ) ) * exp( -(x*x) / (2.*sigma*sigma) )

[fragment_program]
def ps_hblur_effect
    var n : float4[9]
    make_kernel_9x1(n, f_tex, f_texcoord)
    var c : float4
    for a,w in n,f_weights
        c += a * float4(w)
    f_FragColor = c * f_iweights_summ

[fragment_program]
def ps_vblur_effect
    var n : float4[9]
    make_kernel_1x9(n, f_tex, f_texcoord)
    var c : float4
    for a,w in n,f_weights
        c += a * float4(w)
    f_FragColor = c * f_iweights_summ

[fragment_program]
def ps_gradient_effect
    let l = lerp(f_grad_tl,f_grad_bl,float4(f_texcoord.y))
    var r = lerp(f_grad_tr,f_grad_br,float4(f_texcoord.y))
    f_FragColor = lerp(l, r, float4(f_texcoord.x))

[fragment_program]
def ps_blend_add_effect
    let c1 = texture ( f_tex, f_texcoord )
    let c2 = texture ( f_tex2, f_texcoord )
    f_FragColor = c1 + c2

[fragment_program]
def ps_blend_mul_effect
    let c1 = texture ( f_tex, f_texcoord )
    let c2 = texture ( f_tex2, f_texcoord )
    f_FragColor = c1 * c2

[fragment_program]
def ps_blend_crossfade_effect
    let c1 = texture ( f_tex, f_texcoord )
    let c2 = texture ( f_tex2, f_texcoord )
    f_FragColor = lerp(c1, c2, float4(f_blend_factor))

[fragment_program]
def ps_tx_blend_crossfade_effect
    let c1 = texture ( f_tex, f_texcoord )
    let c2 = texture ( f_tex2, f_texcoord )
    let cfactor = texture ( f_tex3, f_texcoord)
    f_FragColor = lerp(c1, c2, cfactor)

[vertex_buffer]
struct EffectVertex
    xy  : float2
    uv  : float2

let private effect_vertices = [[EffectVertex
    xy=float2(-1.0, 1.0), uv=float2(0.0,1.0);
    xy=float2( 1.0, 1.0), uv=float2(1.0,1.0);
    xy=float2( 1.0,-1.0), uv=float2(1.0,0.0);
    xy=float2(-1.0,-1.0), uv=float2(0.0,0.0)
]]

let private effect_indices = [[int 0; 1; 2; 2; 3; 0]]

var private effect_vao = 0u
var private effect_vbo = 0u
var private effect_ebo = 0u

def create_effect_data
    if effect_vao==0u
        glGenVertexArrays(1, safe_addr(effect_vao))
        glBindVertexArray(effect_vao);
    if effect_vbo==0u
        glGenBuffers(1, safe_addr(effect_vbo))
        glBindBuffer(GL_ARRAY_BUFFER, effect_vbo)
        glBufferData(GL_ARRAY_BUFFER, effect_vertices, GL_STATIC_DRAW)
        bind_vertex_buffer(null, type<EffectVertex>)
    if effect_ebo==0u
        glGenBuffers(1, safe_addr(effect_ebo))
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, effect_ebo)
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, effect_indices, GL_STATIC_DRAW)

def bind_effect ( var surf:Surface; prog:uint )
    create_effect_data()
    glBindFramebuffer(GL_FRAMEBUFFER, surf.fbo)
    glViewport(0, 0, surf.size.x, surf.size.y)
    glDisable(GL_DEPTH_TEST)
    glUseProgram(prog)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, effect_ebo)
    glBindVertexArray(effect_vao)

def public create_surface ( var reg:Surface; sz:int2 )
    if sz.x<=0 || sz.y<=0
        panic("can't create surface size {sz}")
    reg <- Surface(sz.x,sz.y)
    glGenFramebuffers(1, unsafe(addr(reg.fbo)))
    glBindFramebuffer(GL_FRAMEBUFFER, reg.fbo)
    glGenTextures(1, unsafe(addr(reg.tex)))
    glBindTexture(GL_TEXTURE_2D, reg.tex)
    glTexImage2D(GL_TEXTURE_2D, 0, int(GL_RGB), reg.size.x, reg.size.y, 0, GL_RGB, GL_UNSIGNED_BYTE, null)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, reg.tex, 0)
    let fboStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER)
    if  fboStatus != GL_FRAMEBUFFER_COMPLETE
        panic("fbo failed {fboStatus} on size {sz}\n")
    if DEBUG_TEXTURE_LIFETIME
        print("create_surface {reg.tex}\n")

def public surface_gen_tex ( var surf:Surface )
    var scopy : Surface
    if DEBUG_TEXTURE_LIFETIME
        print("IN surface_gen_tex:\n")
    create_surface(scopy, surf.size)
    let copy_program = cache_shader_program(vs_any_effect`shader_text,ps_copy_effect`shader_text)
    bind_effect(scopy, copy_program)
    f_tex := surf.tex
    vs_any_effect_bind_uniform(copy_program)
    ps_copy_effect_bind_uniform(copy_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()
    var res <- scopy.tex
    delete scopy
    if DEBUG_TEXTURE_LIFETIME
        print("create copy {res} from {surf.tex}\n")
    return res

def public empty_surface()
    return <- [[Surface]]

def public delete_surface ( var reg:Surface )
    if DEBUG_TEXTURE_LIFETIME
        print("delete surface {reg.tex}\n")
    delete reg

def public surface_gen_image ( var reg:Surface; fileName:string )
    var imgtex = cache_image(fileName)
    var size : int2
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, imgtex)
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, safe_addr(size.x))
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, safe_addr(size.y))
    size = max(size,int2(1))
    create_surface(reg, size)
    let copy_program = cache_shader_program(vs_any_effect`shader_text,ps_copy_effect`shader_text)
    bind_effect(reg, copy_program)
    f_tex := imgtex
    vs_any_effect_bind_uniform(copy_program)
    ps_copy_effect_bind_uniform(copy_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_solid_color ( var reg:Surface; color:float4 )
    bind_effect(reg, 0u)
    glClearColor(color.x, color.y, color.z, color.w)
    glClear(GL_COLOR_BUFFER_BIT)
    bind_ffp()

def public surface_gen_copy ( var surf:Surface; src:Surface )
    if DEBUG_TEXTURE_LIFETIME
        print("copy_image {surf.tex} <- {src.tex}\n")
    let copy_program = cache_shader_program(vs_any_effect`shader_text,ps_copy_effect`shader_text)
    bind_effect ( surf, copy_program )
    f_tex := src.tex
    vs_any_effect_bind_uniform(copy_program)
    ps_copy_effect_bind_uniform(copy_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_height_to_normal ( var surf:Surface; src:Surface; scale:float )
    if DEBUG_TEXTURE_LIFETIME
        print("height_to_normal {surf.tex} <- {src.tex}\n")
    let h2n_program = cache_shader_program(vs_any_effect`shader_text,ps_height_to_normal_effect`shader_text)
    bind_effect ( surf, h2n_program )
    f_tex := src.tex
    f_normal_size = max(scale,0.2)
    vs_any_effect_bind_uniform(h2n_program)
    ps_height_to_normal_effect_bind_uniform(h2n_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_inverse ( var surf:Surface; src:Surface )
    if DEBUG_TEXTURE_LIFETIME
        print("inverse_image {surf.tex} <- {src.tex}\n")
    let inverse_program = cache_shader_program(vs_any_effect`shader_text,ps_inverse_effect`shader_text)
    bind_effect ( surf, inverse_program )
    f_tex := src.tex
    vs_any_effect_bind_uniform(inverse_program)
    ps_copy_effect_bind_uniform(inverse_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_brightness_contrast ( var surf:Surface; src:Surface; brightness,contrast:float )
    if DEBUG_TEXTURE_LIFETIME
        print("brightness_contrast {surf.tex} <- {src.tex}\n")
    let bc_program = cache_shader_program(vs_any_effect`shader_text,ps_brightness_contrast_effect`shader_text)
    bind_effect ( surf, bc_program )
    f_tex := src.tex
    f_brightness = brightness
    f_contrast = contrast
    vs_any_effect_bind_uniform(bc_program)
    ps_brightness_contrast_effect_bind_uniform(bc_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_compose ( var surf:Surface; src:Surface; offset,scale:float2; angle_rad:float; aa:bool )
    if DEBUG_TEXTURE_LIFETIME
        print("compose {surf.tex} <- {src.tex}\n")
    let transform_program = cache_shader_program(vs_transform_effect`shader_text,aa ? ps_copy_aa_effect`shader_text : ps_copy_effect`shader_text)
    bind_effect ( surf, transform_program )
    f_tex := src.tex
    v_tex_transform = compose(
        float4(offset, 0.0, 1.0),
        quat_from_unit_vec_ang(float3(0.,0.,1.), angle_rad),
        float4(scale, 1.0, 1.0))
    vs_transform_effect_bind_uniform(transform_program)
    if aa
        ps_copy_aa_effect_bind_uniform(transform_program)
    else
        ps_copy_effect_bind_uniform(transform_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_greyscale ( var surf:Surface; src:Surface )
    let greyscale_program = cache_shader_program(vs_any_effect`shader_text,ps_greyscale_effect`shader_text)
    bind_effect ( surf, greyscale_program )
    f_tex := src.tex
    vs_any_effect_bind_uniform(greyscale_program)
    ps_greyscale_effect_bind_uniform(greyscale_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_blur ( var surf:Surface; src:Surface; var sigma:float )
    // bindings and weights
    sigma = max(sigma, 0.01)
    f_weights = [[float[9]
        gaussian(-4., sigma);   gaussian(-3., sigma);   gaussian(-2., sigma);   gaussian(-1., sigma);
        gaussian( 0., sigma);
        gaussian( 1., sigma);   gaussian( 2., sigma);   gaussian( 3., sigma);   gaussian( 4., sigma)
    ]]
    f_iweights_summ = 0.
    for w in f_weights
        f_iweights_summ += w
    f_iweights_summ = 1.0 / f_iweights_summ
    // temp surface
    if DEBUG_TEXTURE_LIFETIME
        print("IN surface_gen_blur:\n")
    var temp : Surface
    create_surface(temp, surf.size)
    // horizontal
    let hblur_program = cache_shader_program(vs_any_effect`shader_text,ps_hblur_effect`shader_text)
    bind_effect (temp,hblur_program )
    f_tex := src.tex
    vs_any_effect_bind_uniform(hblur_program)
    ps_hblur_effect_bind_uniform(hblur_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    // vertical
    let vblur_program = cache_shader_program(vs_any_effect`shader_text,ps_vblur_effect`shader_text)
    bind_effect (surf,vblur_program )
    f_tex := temp.tex
    vs_any_effect_bind_uniform(vblur_program)
    ps_vblur_effect_bind_uniform(vblur_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    // back to ffp, also cleanup
    bind_ffp()
    if DEBUG_TEXTURE_LIFETIME
        print("delete temp texture {temp.tex}\n")
    delete temp

def public surface_gen_sobel ( var surf:Surface; src:Surface )
    let sobel_program = cache_shader_program(vs_any_effect`shader_text,ps_sobel_effect`shader_text)
    bind_effect ( surf, sobel_program )
    f_tex := src.tex
    vs_any_effect_bind_uniform(sobel_program)
    ps_sobel_effect_bind_uniform(sobel_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_gen_gradient ( var surf:Surface; top_left,top_right,bottom_left,bottom_right:float4 )
    let gradient_program = cache_shader_program(vs_any_effect`shader_text,ps_gradient_effect`shader_text)
    bind_effect ( surf, gradient_program )
    f_grad_tl = top_left
    f_grad_tr = top_right
    f_grad_bl = bottom_left
    f_grad_br = bottom_right
    vs_any_effect_bind_uniform(gradient_program)
    ps_gradient_effect_bind_uniform(gradient_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

[unused_argument(factor)]
def public surface_blend_Add ( var reg:Surface; src,dst:Surface; factor:float )
    let blend_add_program = cache_shader_program(vs_any_effect`shader_text,ps_blend_add_effect`shader_text)
    bind_effect ( reg, blend_add_program )
    f_tex := src.tex
    f_tex2 := dst.tex
    vs_any_effect_bind_uniform(blend_add_program)
    ps_blend_add_effect_bind_uniform(blend_add_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

[unused_argument(factor)]
def public surface_blend_Multiply ( var reg:Surface; src,dst:Surface; factor:float )
    let blend_mul_program = cache_shader_program(vs_any_effect`shader_text,ps_blend_mul_effect`shader_text)
    bind_effect ( reg, blend_mul_program )
    f_tex := src.tex
    f_tex2 := dst.tex
    vs_any_effect_bind_uniform(blend_mul_program)
    ps_blend_mul_effect_bind_uniform(blend_mul_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_blend_Crossfade  ( var reg:Surface; src,dst:Surface; var factor:float )
    let blend_crossfade_program = cache_shader_program(vs_any_effect`shader_text,ps_blend_crossfade_effect`shader_text)
    bind_effect ( reg, blend_crossfade_program )
    f_blend_factor = clamp(factor,0.,1.)
    f_tex := src.tex
    f_tex2 := dst.tex
    vs_any_effect_bind_uniform(blend_crossfade_program)
    ps_blend_crossfade_effect_bind_uniform(blend_crossfade_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()

def public surface_blend_tex_Crossfade  ( var reg:Surface; src,dst,factor:Surface )
    let tx_blend_crossfade_program = cache_shader_program(vs_any_effect`shader_text,ps_tx_blend_crossfade_effect`shader_text)
    bind_effect ( reg, tx_blend_crossfade_program )
    f_tex := src.tex
    f_tex2 := dst.tex
    f_tex3 := factor.tex
    vs_any_effect_bind_uniform(tx_blend_crossfade_program)
    ps_tx_blend_crossfade_effect_bind_uniform(tx_blend_crossfade_program)
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null)
    bind_ffp()


var G_OUTPUT : array<Material>

def public preview ( var reg:Surface; name,id,outp:string )
    if reg.size.x!=0 && reg.size.y!=0
        var creg : Surface
        if DEBUG_TEXTURE_LIFETIME
            print("IN preview:\n")
        create_surface(creg, reg.size)
        creg.tex = surface_gen_tex(reg)
        if DEBUG_TEXTURE_LIFETIME
            print("preview {creg.tex}\n")
        G_OUTPUT |> push_clone([[Material surf=creg,name=name,id=id,outp=outp]])

def public output ( var reg:Surface; name,id,outp:string )
    if reg.size.x!=0 && reg.size.y!=0
        var creg : Surface
        if DEBUG_TEXTURE_LIFETIME
            print("IN output:\n")
        create_surface(creg, reg.size)
        creg.tex = surface_gen_tex(reg)
        if DEBUG_TEXTURE_LIFETIME
            print("output {creg.tex}\n")
        G_OUTPUT |> push_clone([[Material surf=creg,name=name,id=id,outp=outp]])

def public output_blinn_phong ( var diff,spec,norm:Surface; kD,kS,pS:float; name,id,outp:string )
    if diff.size.x!=0 && diff.size.y!=0
        var cdiff, cspec, cnorm : Surface
        if DEBUG_TEXTURE_LIFETIME
            print("IN output:\n")
        create_surface(cdiff, diff.size)
        cdiff.tex = surface_gen_tex(diff)
        create_surface(cspec, spec.size)
        cspec.tex = surface_gen_tex(spec)
        create_surface(cnorm, norm.size)
        cnorm.tex = surface_gen_tex(norm)
        if DEBUG_TEXTURE_LIFETIME
            print("output pbr {cdiff.tex}\n")
        G_OUTPUT |> push_clone <| [[Material
            surf=cdiff,
            spec=cspec,
            norm=cnorm,
            name=name,
            id=id,
            outp=outp,
            opt <- {{ "kDiff"=>kD; "kSpec"=>kS; "pSpec"=>pS }}
        ]]

def public output ( var reg:float; name,id,outp:string )
    print(" {name}:{outp} = {reg} // {id}\n")

def public output ( var reg:float2; name,id,outp:string )
    print(" {name}:{outp} = {reg} // {id}\n")

def public output ( var reg:float3; name,id,outp:string )
    print(" {name}:{outp} = {reg} // {id}\n")

def public output ( var reg:float4; name,id,outp:string )
    print(" {name}:{outp} = {reg} // {id}\n")
