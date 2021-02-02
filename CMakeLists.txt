IF(NOT DAS_IMGUI_INCLUDED)
    SET(DAS_IMGUI_INCLUDED TRUE)
    MESSAGE(STATUS "dasImGui module included.")

	SET(DAS_IMGUI_DIR ${CMAKE_SOURCE_DIR}/modules/dasImGui)

    LIST(APPEND CMAKE_MODULE_PATH ${DAS_IMGUI_DIR})

	FIND_PACKAGE(imgui)
    FIND_PACKAGE(glfw3)


    IF(NOT imgui_FOUND)
        MESSAGE(STATUS "IMGUI not found. Not building dasImGui.")
	ELSE()
		# libDasModuleImGui
		SET(DAS_IMGUI_MODULE_SRC
			${DAS_IMGUI_DIR}/src/module_imgui.cpp
			${DAS_IMGUI_DIR}/src/module_imgui.inc
			${DAS_IMGUI_DIR}/src/module_imgui.h
			${DAS_IMGUI_DIR}/src/module_imgui.cpp_inc
		)
		ADD_MODULE_LIB(libDasModuleImGui)
		ADD_MODULE_CPP(imgui)
		ADD_MODULE_NATIVE(imgui_boost)
		ADD_LIBRARY(libDasModuleImGui ${DAS_IMGUI_MODULE_SRC})
		TARGET_LINK_LIBRARIES(libDasModuleImGui ${imgui_LIBRARIES})
		ADD_DEPENDENCIES(libDasModuleImGui libDaScript)
		TARGET_INCLUDE_DIRECTORIES(libDasModuleImGui PUBLIC ${imgui_INCLUDE_DIR})
		SETUP_CPP11(libDasModuleImGui)
		# GENERATED IMGUI
		get_target_property(BIND_INCLUDE_DIRS libDasModuleImGui INCLUDE_DIRECTORIES)
		CPP_BIND_AST(
			IMGUI_GENERATE
			generate_imgui.das
			${DAS_IMGUI_DIR}/src/imgui_headers.h
			${DAS_IMGUI_DIR}/src/module_imgui
			${DAS_IMGUI_DIR}/src
			${BIND_INCLUDE_DIRS}
			""
		)
		IF(NOT glfw3_FOUND)
			MESSAGE(STATUS "GLFW3 not found. Not building dasImGuiGLFW.")
		ELSE()
			# libDasModuleImGuiApp
			SET(DAS_IMGUI_APP_MODULE_SRC
				${DAS_IMGUI_DIR}/src/module_imgui_app.cpp
				${DAS_IMGUI_DIR}/src/imgui_impl_glfw.cpp
				${DAS_IMGUI_DIR}/src/imgui_impl_glfw.h
				${DAS_IMGUI_DIR}/src/imgui_impl_opengl2.cpp
				${DAS_IMGUI_DIR}/src/imgui_impl_opengl2.h
				${DAS_IMGUI_DIR}/example/imgui_opengl2.das
			)
			ADD_MODULE_LIB(libDasModuleImGuiApp)
			ADD_MODULE_CPP(imgui_app)
			ADD_LIBRARY(libDasModuleImGuiApp ${DAS_IMGUI_APP_MODULE_SRC})
			TARGET_LINK_LIBRARIES(libDasModuleImGuiApp ${glfw_LIBRARIES})
			ADD_DEPENDENCIES(libDasModuleImGuiApp libDaScript libDasModuleImGui)
			TARGET_INCLUDE_DIRECTORIES(libDasModuleImGuiApp PUBLIC ${imgui_INCLUDE_DIR} ${glfw_INCLUDE_DIR})
			SETUP_CPP11(libDasModuleImGuiApp)
		ENDIF()
	ENDIF()
ENDIF()