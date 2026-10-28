cmake_minimum_required(VERSION 3.18)
project(nim_esphome_ext LANGUAGES C)

find_program(NIM_EXECUTABLE NAMES nim REQUIRED)

set(NIM_SRC "${CMAKE_CURRENT_SOURCE_DIR}/src/nim_esphome.nim")
set(NIM_OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")

if(WIN32)
  set(NIM_LIB_NAME "nim_esphome_ext.dll")
elseif(APPLE)
  set(NIM_LIB_NAME "libnim_esphome_ext.dylib")
else()
  set(NIM_LIB_NAME "libnim_esphome_ext.so")
endif()

set(NIM_LIB_PATH "${NIM_OUT_DIR}/${NIM_LIB_NAME}")

add_custom_command(
  OUTPUT "${NIM_LIB_PATH}"
  COMMAND ${NIM_EXECUTABLE} c --app:lib --mm:orc --threads:on -d:release
          --out:${NIM_LIB_PATH}
          "${NIM_SRC}"
  DEPENDS "${NIM_SRC}"
  COMMENT "Compiling Nim native extension library ${NIM_LIB_NAME}"
  VERBATIM
)

add_custom_target(nim_esphome_ext ALL DEPENDS "${NIM_LIB_PATH}")

install(FILES "${NIM_LIB_PATH}" DESTINATION "nim_esphome")
