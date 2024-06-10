// this file is generated via daScript automatic C++ binder
// all user modifications will be lost after this file is re-generated

template <> struct cast_arg<ImNodesIO::EmulateThreeButtonMouseStruct> {
	static __forceinline const ImNodesIO::EmulateThreeButtonMouseStruct & to ( Context & ctx, SimNode * node ) {
		vec4f res = node->eval(ctx);
		return * cast<ImNodesIO::EmulateThreeButtonMouseStruct *>::to(res);
	}
};
template <> struct cast_arg<ImNodesIO::LinkDetachWithModifierClickStruct> {
	static __forceinline const ImNodesIO::LinkDetachWithModifierClickStruct & to ( Context & ctx, SimNode * node ) {
		vec4f res = node->eval(ctx);
		return * cast<ImNodesIO::LinkDetachWithModifierClickStruct *>::to(res);
	}
};
template <> struct cast_arg<ImNodesIO> {
	static __forceinline const ImNodesIO & to ( Context & ctx, SimNode * node ) {
		vec4f res = node->eval(ctx);
		return * cast<ImNodesIO *>::to(res);
	}
};
template <> struct cast_arg<ImNodesStyle> {
	static __forceinline const ImNodesStyle & to ( Context & ctx, SimNode * node ) {
		vec4f res = node->eval(ctx);
		return * cast<ImNodesStyle *>::to(res);
	}
};
