# SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
# Tests des règles métier, compilables seuls (sans les autres dépendances de l'appli) :
#   cmake -S gui/tests -B build-tests && cmake --build build-tests && ctest --test-dir build-tests
cmake_minimum_required(VERSION 3.16)
project(macnplay-tests LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
enable_testing()
find_package(Qt6 COMPONENTS Test REQUIRED)
add_executable(macnplay-rules-test rulestest.cpp)
target_include_directories(macnplay-rules-test PRIVATE ../include)
target_link_libraries(macnplay-rules-test Qt6::Test)
add_test(NAME macnplay-rules COMMAND macnplay-rules-test)
