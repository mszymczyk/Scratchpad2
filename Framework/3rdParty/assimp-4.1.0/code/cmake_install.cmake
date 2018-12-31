# Install script for directory: F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "C:/Program Files/Assimp")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/lib/Debug/assimp-vc140-mt.lib")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/lib/Release/assimp-vc140-mt.lib")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/lib/MinSizeRel/assimp-vc140-mt.lib")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/lib/RelWithDebInfo/assimp-vc140-mt.lib")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/bin/Debug/assimp-vc140-mt.dll")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/bin/Release/assimp-vc140-mt.dll")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/bin/MinSizeRel/assimp-vc140-mt.dll")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/bin/RelWithDebInfo/assimp-vc140-mt.dll")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xassimp-devx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/assimp" TYPE FILE FILES
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/anim.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/ai_assert.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/camera.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/color4.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/color4.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/config.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/defs.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Defines.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/cfileio.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/light.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/material.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/material.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/matrix3x3.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/matrix3x3.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/matrix4x4.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/matrix4x4.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/mesh.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/postprocess.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/quaternion.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/quaternion.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/scene.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/metadata.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/texture.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/types.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/vector2.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/vector2.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/vector3.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/vector3.inl"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/version.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/cimport.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/importerdesc.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Importer.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/DefaultLogger.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/ProgressHandler.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/IOStream.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/IOSystem.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Logger.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/LogStream.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/NullLogger.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/cexport.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Exporter.hpp"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/DefaultIOStream.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/DefaultIOSystem.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/SceneCombiner.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xassimp-devx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/assimp/Compiler" TYPE FILE FILES
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Compiler/pushpack1.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Compiler/poppack1.h"
    "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/../include/assimp/Compiler/pstdint.h"
    )
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE FILE FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/Debug/assimp-vc140-mt.pdb")
  endif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE FILE FILES "F:/_Scratchpad2/Framework/3rdParty/assimp-4.1.0/code/RelWithDebInfo/assimp-vc140-mt.pdb")
  endif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
endif()

