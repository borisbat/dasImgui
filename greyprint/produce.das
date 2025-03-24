options gen2
options indenting = 4

module produce

require strings
require daslib/contracts
require instructions

// produce

def to_reg(v : int; vdef : string = "r_nop") {
    return v == -1 ? vdef : "r_{v}"
}

def to_reg_scalar(v : int) {
    return v == -1 ? "0.0f" : "r_{v}"
}

def to_reg_vector2(v : int) {
    return v == -1 ? "float2(0.0f)" : "r_{v}"
}

def to_reg_vector3(v : int) {
    return v == -1 ? "float3(0.0f)" : "r_{v}"
}

def to_reg_vector4(v : int) {
    return v == -1 ? "float4(0.0f)" : "r_{v}"
}

def to_reg_surface(v : int) {
    return to_reg(v, "empty_surface()")
}

def to_reg_any(v : int; _type : string) {
    if (_type == TYPE_SCALAR) {
        return to_reg_scalar(v)
    } elif (_type == TYPE_VECTOR2) {
        return to_reg_vector2(v)
    } elif (_type == TYPE_VECTOR3) {
        return to_reg_vector3(v)
    } elif (_type == TYPE_VECTOR4) {
        return to_reg_vector4(v)
    } elif (_type == TYPE_SURFACE) {
        return to_reg_surface(v)
    } else {
        return to_reg(v)
    }
}

def to_produce(v : int) {
    return string(v)
}

def to_produce(f : float) {
    return string(f) + "f"
}

[expect_any_vector_type(v)]
def to_produce(v : auto(VecT)) {
    let tname = typeinfo undecorated_typename(type<VecT -const>)
    static_if (typeinfo vector_dim(type<VecT>) == 2) {
        return "{tname}({to_produce(v.x)},{to_produce(v.y)})"
    } static_elif (typeinfo vector_dim(type<VecT>) == 3) {
        return "{tname}({to_produce(v.x)},{to_produce(v.y)},{to_produce(v.z)})"
    } static_elif (typeinfo vector_dim(type<VecT>) == 4) {
        return "{tname}({to_produce(v.x)},{to_produce(v.y)},{to_produce(v.z)},{to_produce(v.w)})"
    }
}
