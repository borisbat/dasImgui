IF((NOT DAS_IMGUI_INCLUDED) AND ((NOT ${DAS_IMGUI_DISABLED}) OR (NOT DEFINED DAS_IMGUI_DISABLED)))
    SET(DAS_IMGUI_INCLUDED TRUE)
    MESSAGE(STATUS "dasImgui module included.")

	SET(DAS_IMGUI_DIR ${CMAKE_SOURCE_DIR}/modules/dasImgui)

    LIST(APPEND CMAKE_MODULE_PATH ${DAS_IMGUI_DIR})

    FIND_PACKAGE(Vulkan)

	ADD_DEFINITIONS(-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1)

	SET(DAS_GLFW_DIR ${CMAKE_SOURCE_DIR}/modules/dasGlfw)
	SET(GLFW_INCLUDE_DIR ${DAS_GLFW_DIR}/glfw/include)
	IF(APPLE)
		find_library(COCOA_LIBRARY Cocoa)
		find_library(IOKIT_LIBRARY IOKit)
		find_library(METAL_LIBRARY Metal)
		find_library(QUARTZCORE_LIBRARY QuartzCore)
		SET(GLFW_LIBRARIES
			${DAS_GLFW_DIR}/glfw/lib/libglfw3.a
			${COCOA_LIBRARY}
			${IOKIT_LIBRARY}
			${METAL_LIBRARY}
			${QUARTZCORE_LIBRARY}
		)
	ELSEIF(UNIX)
		SET(GLFW_LIBRARIES ${DAS_GLFW_DIR}/glfw/lib/libglfw3.a)
	ELSE()
		SET(GLFW_LIBRARIES ${DAS_GLFW_DIR}/glfw/lib/glfw3.lib)
	ENDIF()

	# imgui
	SET(imgui_INCLUDE_DIR ${DAS_IMGUI_DIR}/imgui)
	SET(DAS_IMGUI_SRC
		${imgui_INCLUDE_DIR}/imconfig.h
		${imgui_INCLUDE_DIR}/imgui.cpp
		${imgui_INCLUDE_DIR}/imgui.h
		${imgui_INCLUDE_DIR}/imgui_demo.cpp
		${imgui_INCLUDE_DIR}/imgui_draw.cpp
		${imgui_INCLUDE_DIR}/imgui_internal.h
		${imgui_INCLUDE_DIR}/imgui_tables.cpp
		${imgui_INCLUDE_DIR}/imgui_widgets.cpp
		${imgui_INCLUDE_DIR}/imstb_rectpack.h
		${imgui_INCLUDE_DIR}/imstb_textedit.h
		${imgui_INCLUDE_DIR}/imstb_truetype.h
	)

	# imnodes
	SET(imnodes_INCLUDE_DIR ${DAS_IMGUI_DIR}/imnodes)
	SET(DAS_IMNODES_SRC
		${imnodes_INCLUDE_DIR}/imnodes.cpp
		${imnodes_INCLUDE_DIR}/imnodes.h
	)

	# imgui node editor
	SET(imgui_node_editor_INCLUDE_DIR ${DAS_IMGUI_DIR}/imgui-node-editor)
	SET(DAS_IMGUI_NODE_EDITOR_SRC
		${imgui_node_editor_INCLUDE_DIR}/crude_json.cpp
		${imgui_node_editor_INCLUDE_DIR}/crude_json.h
		${imgui_node_editor_INCLUDE_DIR}/imgui_bezier_math.h
		${imgui_node_editor_INCLUDE_DIR}/imgui_bezier_math.inl
		${imgui_node_editor_INCLUDE_DIR}/imgui_canvas.cpp
		${imgui_node_editor_INCLUDE_DIR}/imgui_canvas.h
		${imgui_node_editor_INCLUDE_DIR}/imgui_extra_math.h
		${imgui_node_editor_INCLUDE_DIR}/imgui_extra_math.inl
		${imgui_node_editor_INCLUDE_DIR}/imgui_node_editor.cpp
		${imgui_node_editor_INCLUDE_DIR}/imgui_node_editor.h
		${imgui_node_editor_INCLUDE_DIR}/imgui_node_editor_api.cpp
		${imgui_node_editor_INCLUDE_DIR}/imgui_node_editor_internal.h
		${imgui_node_editor_INCLUDE_DIR}/imgui_node_editor_internal.inl
	)

	SET(DAS_IMGUI_BIND_DIR ${DAS_IMGUI_DIR})
	SET(DAS_IMGUI_BIND_MODULE_SRC
		${DAS_IMGUI_BIND_DIR}/src/need_dasIMGUI.h
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.h
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.cpp
	# user include
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.main.cpp
	# generated binding includes
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.alias.add.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.dummy.add.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.enum.add.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.enum.class.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.enum.decl.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.enum.decl.cast.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.struct.add.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.struct.postadd.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.struct.class.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.struct.decl.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.struct.impl.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.struct.cast.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func.reg.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func.decl.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func.aot.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func.aot.decl.inc
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.const.inc
	# generated functions
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_1.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_2.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_3.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_4.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_5.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_6.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_7.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_8.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_9.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_10.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_11.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_12.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_13.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_14.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_15.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_16.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_17.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_18.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_19.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_20.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_21.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_22.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_23.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_24.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_25.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_26.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_27.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_28.cpp
		${DAS_IMGUI_BIND_DIR}/src/dasIMGUI.func_29.cpp
	)

	SET(DAS_IMNODES_BIND_DIR ${DAS_IMGUI_DIR})
	SET(DAS_IMNODES_BIND_MODULE_SRC
		${DAS_IMNODES_BIND_DIR}/src/need_dasIMNODES.h
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.h
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.cpp
	# user include
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.main.cpp
	# generated binding includes
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.alias.add.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.dummy.add.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.enum.add.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.enum.class.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.enum.decl.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.enum.decl.cast.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.struct.add.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.struct.postadd.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.struct.class.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.struct.decl.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.struct.impl.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.struct.cast.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func.reg.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func.decl.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func.aot.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func.aot.decl.inc
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.const.inc
	# generated functions
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func_1.cpp
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func_2.cpp
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func_3.cpp
		${DAS_IMNODES_BIND_DIR}/src/dasIMNODES.func_4.cpp
	)

	SET(DAS_IMGUI_NODE_EDITOR_BIND_DIR ${DAS_IMGUI_DIR})
	SET(DAS_IMGUI_NODE_EDITOR_BIND_MODULE_SRC
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/need_dasIMGUI_NODE_EDITOR.h
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.h
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.cpp
	# user include
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.main.cpp
	# generated binding includes
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.alias.add.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.dummy.add.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.enum.add.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.enum.class.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.enum.decl.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.enum.decl.cast.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.struct.add.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.struct.postadd.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.struct.class.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.struct.decl.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.struct.impl.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.struct.cast.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func.reg.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func.decl.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func.aot.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func.aot.decl.inc
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.const.inc
	# generated functions
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func_1.cpp
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func_2.cpp
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func_3.cpp
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func_4.cpp
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func_5.cpp
		${DAS_IMGUI_NODE_EDITOR_BIND_DIR}/src/dasIMGUI_NODE_EDITOR.func_6.cpp
	)

	ADD_MODULE_LIB(libDasModuleImGui)
	ADD_MODULE_CPP(dasIMGUI)
	ADD_MODULE_CPP(dasIMNODES)
	ADD_MODULE_CPP(dasIMGUI_NODE_EDITOR)
	ADD_MODULE_DAS(imgui daslib imgui_boost)
	ADD_MODULE_DAS(imgui daslib imnodes_boost)
	ADD_MODULE_DAS(imgui daslib imgui_node_editor_boost)
	ADD_LIBRARY(libDasModuleImGui
		${DAS_IMGUI_BIND_MODULE_SRC}
		${DAS_IMNODES_BIND_MODULE_SRC}
		${DAS_IMGUI_NODE_EDITOR_BIND_MODULE_SRC}
		${DAS_IMGUI_SRC} ${DAS_IMNODES_SRC} ${DAS_IMGUI_NODE_EDITOR_SRC})
	#TARGET_LINK_LIBRARIES(libDasModuleImGui ${imgui_LIBRARIES})
	# ADD_DEPENDENCIES(libDasModuleImGui )
	TARGET_INCLUDE_DIRECTORIES(libDasModuleImGui PUBLIC ${imgui_INCLUDE_DIR} ${imnodes_INCLUDE_DIR} ${imgui_node_editor_INCLUDE_DIR} ${DAS_IMGUI_BIND_DIR}/src)
	SETUP_CPP11(libDasModuleImGui)

    install(DIRECTORY ${PROJECT_SOURCE_DIR}/modules/dasImgui/daslib
        DESTINATION ${DAS_INSTALL_MODULESDIR}/dasImgui
        FILES_MATCHING
        PATTERN "*.das"
    )
    install(FILES
			${PROJECT_SOURCE_DIR}/modules/dasImgui/example/imgui_opengl2.das
			${PROJECT_SOURCE_DIR}/modules/dasImgui/example/imgui_demo.das
        DESTINATION ${DAS_INSTALL_EXAMPLESDIR}/imgui
    )
    file(GLOB DAS_IMGUI_EXAMPLES
        ${PROJECT_SOURCE_DIR}/modules/dasImgui/greyprint/*.das
    )
    install(FILES ${DAS_IMGUI_EXAMPLES}
        DESTINATION ${DAS_INSTALL_EXAMPLESDIR}/imgui/greyprint
    )

	install(FILES ${PROJECT_SOURCE_DIR}/modules/dasImgui/imgui/LICENSE.txt DESTINATION ${DAS_INSTALL_DOCDIR} RENAME IMGUI.LICENSE)
	install(FILES ${PROJECT_SOURCE_DIR}/modules/dasImgui/imgui-node-editor/LICENSE DESTINATION ${DAS_INSTALL_DOCDIR} RENAME IMGUI-NODE-EDITOR.LICENSE)
	install(FILES ${PROJECT_SOURCE_DIR}/modules/dasImgui/imnodes/LICENSE.md DESTINATION ${DAS_INSTALL_DOCDIR} RENAME IMNODES.LICENSE)

	FIND_PACKAGE(OpenGL)
	IF(NOT OPENGL_FOUND)
		MESSAGE(STATUS "OpenGL not found.")
	ELSE()
		# libDasModuleImGuiApp
		SET(DAS_IMGUI_APP_MODULE_SRC
			${DAS_IMGUI_DIR}/src/module_imgui_app.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_glfw.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_glfw.h
			${imgui_INCLUDE_DIR}/backends/imgui_impl_opengl3.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_opengl3.h
			${DAS_IMGUI_DIR}/gl3w/GL/gl3w.cpp
			${DAS_IMGUI_DIR}/gl3w/GL/gl3w.h
			${DAS_IMGUI_DIR}/example/imgui_demo.das
			${DAS_IMGUI_DIR}/example/imgui_opengl2.das
			${DAS_IMGUI_DIR}/example/imnode_editor.das
		)
		ADD_MODULE_LIB(libDasModuleImGuiApp)
		ADD_MODULE_CPP(imgui_app)
		ADD_LIBRARY(libDasModuleImGuiApp ${DAS_IMGUI_APP_MODULE_SRC})
		TARGET_LINK_LIBRARIES(libDasModuleImGuiApp
			${GLFW_LIBRARIES}
			${OPENGL_LIBRARIES}
		)
		# ADD_DEPENDENCIES(libDasModuleImGuiApp libDasModuleImGui)
		TARGET_INCLUDE_DIRECTORIES(libDasModuleImGuiApp PUBLIC
			${imgui_INCLUDE_DIR}
			${DAS_IMGUI_DIR}/gl3w
			${GLFW_INCLUDE_DIR}
		)
		target_compile_definitions(libDasModuleImGuiApp PUBLIC IMGUI_IMPL_OPENGL_LOADER_GL3W)
		SETUP_CPP11(libDasModuleImGuiApp)
	ENDIF()

	# demo AOT
	add_custom_target(dasImguiOpenGL_AOT)
	SET(IMGUI_OPENGL_AOT_GENERATED_SRC)
	DAS_AOT("${DAS_IMGUI_DIR}/example/imgui_demo.das" IMGUI_OPENGL_AOT_GENERATED_SRC dasImguiOpenGL_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/example/imgui_opengl2.das" IMGUI_OPENGL_AOT_GENERATED_SRC dasImguiOpenGL_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/daslib/imgui_boost.das" IMGUI_OPENGL_AOT_GENERATED_SRC dasImguiOpenGL_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/daslib/imgui_node_editor_boost.das" IMGUI_OPENGL_AOT_GENERATED_SRC dasImguiOpenGL_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasGlfw/dasglfw/glfw_boost.das" IMGUI_OPENGL_AOT_GENERATED_SRC dasImguiOpenGL_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasOpenGL/opengl/opengl_boost.das" IMGUI_OPENGL_AOT_GENERATED_SRC dasImguiOpenGL_AOT daScript)
	SOURCE_GROUP_FILES("aot stub" IMGUI_OPENGL_AOT_GENERATED_SRC)

	# now, the demo
	SET(IMGUI_OPENGL_DEMO_SRC
		${DAS_IMGUI_DIR}/example/imgui_opengl_aot.cpp
		${DAS_MODULES_NEED_INC}
	)
	SOURCE_GROUP_FILES("main" IMGUI_OPENGL_DEMO_SRC)
	add_executable(dasImguiOpenGL ${IMGUI_OPENGL_DEMO_SRC} ${IMGUI_OPENGL_AOT_GENERATED_SRC})
	TARGET_LINK_LIBRARIES(dasImguiOpenGL libDaScript libDaScriptAot Threads::Threads)
	# ADD_DEPENDENCIES(dasImguiOpenGL libDaScript)
	ADD_DEPENDENCIES(dasImguiOpenGL dasImguiOpenGL_AOT libDaScriptAot)
	TARGET_INCLUDE_DIRECTORIES(dasImguiOpenGL PUBLIC ${imgui_INCLUDE_DIR} ${GLFW_INCLUDE_DIR} ${imnodes_INCLUDE_DIR} ${imgui_node_editor_INCLUDE_DIR})
	SETUP_CPP11(dasImguiOpenGL)
	SETUP_LTO(dasImguiOpenGL)
	ADD_EXAMPLE(dasImguiOpenGL)

	# GREYPRINT AOT
	add_custom_target(GREYPRINT_AOT)
	SET(GREYPRINT_GENERATED_SRC)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/command_que.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/greyprint.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/guid_2_id.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/instructions.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/instructions_math.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/instructions_model.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/instructions_ui.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/model.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/model_eval.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/preview.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/produce.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/greyprint/undo_stack.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	# imgui
	DAS_AOT("${DAS_IMGUI_DIR}/daslib/imgui_boost.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/daslib/imgui_node_editor_boost.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	# glfw
	DAS_AOT("${DAS_IMGUI_DIR}/../dasGlfw/dasglfw/glfw_boost.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	# opengl
	DAS_AOT("${DAS_IMGUI_DIR}/../dasOpenGL/opengl/opengl_boost.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasOpenGL/opengl/opengl_state.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasOpenGL/opengl/opengl_ttf.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasOpenGL/opengl/opengl_gen.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasOpenGL/opengl/opengl_cache.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	# glsl
	DAS_AOT("${DAS_IMGUI_DIR}/../dasGlsl/glsl/glsl_common.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	DAS_AOT("${DAS_IMGUI_DIR}/../dasGlsl/glsl/geom_gen.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	# ttf
	DAS_AOT("${DAS_IMGUI_DIR}/../dasStbTrueType/ttf/stb_ttf_common.das" GREYPRINT_GENERATED_SRC GREYPRINT_AOT daScript)
	SOURCE_GROUP_FILES("aot stub" GREYPRINT_GENERATED_SRC)

	# now, the demo
	SET(GREYPRINT_SRC
		${DAS_IMGUI_DIR}/greyprint/greyprint.cpp
		${DAS_MODULES_NEED_INC}
	)
	SOURCE_GROUP_FILES("main" GREYPRINT_SRC)
	add_executable(Greyprint ${GREYPRINT_SRC} ${GREYPRINT_GENERATED_SRC})
	TARGET_LINK_LIBRARIES(Greyprint libDaScript libDaScriptAot Threads::Threads)
	# ADD_DEPENDENCIES(Greyprint libDaScript)
	ADD_DEPENDENCIES(Greyprint GREYPRINT_AOT libDaScriptAot)
	TARGET_INCLUDE_DIRECTORIES(Greyprint PUBLIC ${imgui_INCLUDE_DIR} ${GLFW_INCLUDE_DIR} ${imnodes_INCLUDE_DIR} ${imgui_node_editor_INCLUDE_DIR})
	SETUP_CPP11(Greyprint)
	SETUP_LTO(Greyprint)
	ADD_EXAMPLE(Greyprint)

	IF ((NOT Vulkan_FOUND) OR (NOT EXISTS "${DAS_IMGUI_DIR}/../dasVulkan/include/dasVulkan/module.h"))
		MESSAGE(STATUS "Vulkan not found. Not building dasImguiVulkan.")
	ELSE()
		# libDasModuleImGuiVulkan
		SET(DAS_IMGUI_VULKAN_MODULE_SRC
			${DAS_IMGUI_DIR}/src/module_imgui_vulkan.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_vulkan.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_vulkan.h
			${DAS_IMGUI_DIR}/example/imgui_demo.das
			${DAS_IMGUI_DIR}/example/imgui_vulkan.das
		)
		ADD_MODULE_LIB(libDasModuleImGuiVulkan)
		ADD_MODULE_CPP(imgui_vulkan)
		ADD_LIBRARY(libDasModuleImGuiVulkan ${DAS_IMGUI_VULKAN_MODULE_SRC})
		TARGET_LINK_LIBRARIES(libDasModuleImGuiVulkan ${GLFW_LIBRARIES})
		# ADD_DEPENDENCIES(libDasModuleImGuiVulkan libDasModuleImGui)
		TARGET_INCLUDE_DIRECTORIES(libDasModuleImGuiVulkan PUBLIC
			${imgui_INCLUDE_DIR}
			${GLFW_INCLUDE_DIR}
			${Vulkan_INCLUDE_DIR})
		SETUP_CPP11(libDasModuleImGuiVulkan)

		# GENERATED IMGUI VULKAN
		DAS_CPP_BIND_AST(
			IMGUI_GENERATE_VULKAN
			generate_vulkan.das
			${imgui_INCLUDE_DIR}/backends/imgui_impl_vulkan.h
			${DAS_IMGUI_DIR}/src/module_imgui_vulkan
			${DAS_IMGUI_DIR}/src
			"${Vulkan_INCLUDE_DIR};${imgui_INCLUDE_DIR}"
			""
		)
	ENDIF()

ENDIF()
