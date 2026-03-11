IF(NOT DAS_IMGUI_INCLUDED)
    SET(DAS_IMGUI_INCLUDED TRUE)
    MESSAGE(STATUS "dasImgui module included.")

	SET(DAS_IMGUI_DIR ${CMAKE_CURRENT_LIST_DIR})

	ADD_DEFINITIONS(-DIMGUI_DISABLE_OBSOLETE_FUNCTIONS=1)

	SET(DAS_GLFW_DIR ${CMAKE_SOURCE_DIR}/modules/dasGlfw)
	SET(GLFW_INCLUDE_DIR ${DAS_GLFW_DIR}/glfw/include)

	# imgui via FetchContent (download at configure time — imgui is not a CMake project)
	include(FetchContent)
	SET(IMGUI_VERSION "1.90.6-docking")
	FetchContent_Declare(imgui_src
		URL https://github.com/ocornut/imgui/archive/refs/tags/v${IMGUI_VERSION}.tar.gz
		URL_HASH SHA256=fc7f81d009ef718917aee0ac3ea1c74c8a5cfc8016049ad153b4d91d302b8aef
		SOURCE_DIR ${DAS_IMGUI_DIR}/imgui
	)
	FetchContent_MakeAvailable(imgui_src)

	# Patch: add data() method to ImVector (needed by daScript's ast_handle.h ManagedVectorAnnotation)
	FILE(READ ${DAS_IMGUI_DIR}/imgui/imgui.h IMGUI_H_CONTENT)
	IF(NOT IMGUI_H_CONTENT MATCHES "inline T\\*           data\\(\\)")
		STRING(REPLACE
			"inline T*           end()                               { return Data + Size; }"
			"inline T*           data()                              { return Data; }\n    inline const T*     data() const                        { return Data; }\n    inline T*           end()                               { return Data + Size; }"
			IMGUI_H_CONTENT "${IMGUI_H_CONTENT}")
		FILE(WRITE ${DAS_IMGUI_DIR}/imgui/imgui.h "${IMGUI_H_CONTENT}")
		MESSAGE(STATUS "Patched imgui.h: added data() method to ImVector")
	ENDIF()

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

	SET(DAS_IMGUI_BIND_MODULE_SRC
		${DAS_IMGUI_DIR}/src/need_dasIMGUI.h
		${DAS_IMGUI_DIR}/src/dasIMGUI.h
		${DAS_IMGUI_DIR}/src/dasIMGUI.cpp
	# user include
		${DAS_IMGUI_DIR}/src/dasIMGUI.main.cpp
	# generated binding includes
		${DAS_IMGUI_DIR}/src/dasIMGUI.alias.add.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.dummy.add.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.enum.add.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.enum.class.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.enum.decl.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.enum.decl.cast.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.struct.add.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.struct.postadd.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.struct.class.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.struct.decl.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.struct.impl.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.struct.cast.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.func.reg.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.func.decl.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.func.aot.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.func.aot.decl.inc
		${DAS_IMGUI_DIR}/src/dasIMGUI.const.inc
	# generated functions
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_1.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_2.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_3.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_4.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_5.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_6.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_7.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_8.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_9.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_10.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_11.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_12.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_13.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_14.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_15.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_16.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_17.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_18.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_19.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_20.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_21.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_22.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_23.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_24.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_25.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_26.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_27.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_28.cpp
		${DAS_IMGUI_DIR}/src/dasIMGUI.func_29.cpp
	)

	# core imgui module
	ADD_MODULE_CPP(dasIMGUI)
	ADD_MODULE_DAS(imgui daslib imgui_boost)
	ADD_MODULE_LIB(libDasModuleImGui dasModuleImgui
		${DAS_IMGUI_BIND_MODULE_SRC}
		${DAS_IMGUI_SRC})

	IF(WIN32)
		SET(IMGUI_PUBLIC_ATTR "__declspec\(dllexport\)")
	ELSE()
		SET(IMGUI_PUBLIC_ATTR "__attribute__\(\(visibility\(\"default\"\)\)\)")
	ENDIF()
	TARGET_COMPILE_DEFINITIONS(dasModuleImgui PRIVATE IMGUI_API=${IMGUI_PUBLIC_ATTR})

	MACRO(SETUP_IMGUI lib)
		TARGET_INCLUDE_DIRECTORIES(${lib} PRIVATE ${imgui_INCLUDE_DIR} ${DAS_IMGUI_DIR}/src)
		SETUP_CPP11(${lib})
	ENDMACRO()
	SETUP_IMGUI(libDasModuleImGui)
	SETUP_IMGUI(dasModuleImgui)

	# imgui_app module (GLFW + OpenGL3 backend)
	FIND_PACKAGE(OpenGL)
	IF(NOT OPENGL_FOUND)
		MESSAGE(STATUS "OpenGL not found.")
	ELSE()
		SET(DAS_IMGUI_APP_MODULE_SRC
			${DAS_IMGUI_DIR}/src/module_imgui_app.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_glfw.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_glfw.h
			${imgui_INCLUDE_DIR}/backends/imgui_impl_opengl3.cpp
			${imgui_INCLUDE_DIR}/backends/imgui_impl_opengl3.h
			${DAS_IMGUI_DIR}/gl3w/GL/gl3w.cpp
			${DAS_IMGUI_DIR}/gl3w/GL/gl3w.h
		)

		ADD_MODULE_CPP(imgui_app)
		ADD_MODULE_LIB(libDasModuleImGuiApp imguiApp ${DAS_IMGUI_APP_MODULE_SRC})
		TARGET_COMPILE_DEFINITIONS(libDasModuleImGuiApp PRIVATE IMGUI_IMPL_API=${IMGUI_PUBLIC_ATTR})
		MACRO(SETUP_IMGUIAPP lib)
			TARGET_LINK_LIBRARIES(${lib} PUBLIC ${COCOA_LIBRARY} ${OPENGL_LIBRARIES})
			IF(UNIX AND NOT APPLE)
				target_link_libraries(${lib} PUBLIC X11)
			ENDIF()
			TARGET_INCLUDE_DIRECTORIES(${lib} PRIVATE
				${imgui_INCLUDE_DIR}
				${GLFW_INCLUDE_DIR}
				${DAS_IMGUI_DIR}/gl3w
			)
			target_compile_definitions(${lib} PUBLIC IMGUI_IMPL_OPENGL_LOADER_GL3W)
			SETUP_CPP11(${lib})
		ENDMACRO()
		SETUP_IMGUIAPP(libDasModuleImGuiApp)
		TARGET_LINK_LIBRARIES(libDasModuleImGuiApp PUBLIC libDasModuleImGui libDasModuleGlfw)
		SETUP_IMGUIAPP(imguiApp)
		TARGET_LINK_LIBRARIES(imguiApp PUBLIC dasModuleImgui dasModuleGlfw)
		set_target_properties(imguiApp PROPERTIES
			INSTALL_RPATH "$ORIGIN/../dasImgui;$ORIGIN/../dasGlfw"
			BUILD_WITH_INSTALL_RPATH TRUE
			SKIP_BUILD_RPATH FALSE
		)
	ENDIF()

ENDIF()
