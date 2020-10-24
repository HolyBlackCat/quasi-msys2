# This file contains CMake configuration.

SET(CMAKE_SYSTEM_NAME Windows)
SET(CMAKE_CROSSCOMPILING FALSE)

SET(CMAKE_FIND_ROOT_PATH $ENV{MSYSTEM_PREFIX})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
