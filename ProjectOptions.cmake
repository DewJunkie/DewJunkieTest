include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(DewJunkieTest_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(DewJunkieTest_setup_options)
  option(DewJunkieTest_ENABLE_HARDENING "Enable hardening" ON)
  option(DewJunkieTest_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    DewJunkieTest_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    DewJunkieTest_ENABLE_HARDENING
    OFF)

  DewJunkieTest_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR DewJunkieTest_PACKAGING_MAINTAINER_MODE)
    option(DewJunkieTest_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(DewJunkieTest_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(DewJunkieTest_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(DewJunkieTest_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(DewJunkieTest_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(DewJunkieTest_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(DewJunkieTest_ENABLE_PCH "Enable precompiled headers" OFF)
    option(DewJunkieTest_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(DewJunkieTest_ENABLE_IPO "Enable IPO/LTO" ON)
    option(DewJunkieTest_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(DewJunkieTest_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(DewJunkieTest_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(DewJunkieTest_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(DewJunkieTest_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(DewJunkieTest_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(DewJunkieTest_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(DewJunkieTest_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(DewJunkieTest_ENABLE_PCH "Enable precompiled headers" OFF)
    option(DewJunkieTest_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      DewJunkieTest_ENABLE_IPO
      DewJunkieTest_WARNINGS_AS_ERRORS
      DewJunkieTest_ENABLE_USER_LINKER
      DewJunkieTest_ENABLE_SANITIZER_ADDRESS
      DewJunkieTest_ENABLE_SANITIZER_LEAK
      DewJunkieTest_ENABLE_SANITIZER_UNDEFINED
      DewJunkieTest_ENABLE_SANITIZER_THREAD
      DewJunkieTest_ENABLE_SANITIZER_MEMORY
      DewJunkieTest_ENABLE_UNITY_BUILD
      DewJunkieTest_ENABLE_CLANG_TIDY
      DewJunkieTest_ENABLE_CPPCHECK
      DewJunkieTest_ENABLE_COVERAGE
      DewJunkieTest_ENABLE_PCH
      DewJunkieTest_ENABLE_CACHE)
  endif()

  DewJunkieTest_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (DewJunkieTest_ENABLE_SANITIZER_ADDRESS OR DewJunkieTest_ENABLE_SANITIZER_THREAD OR DewJunkieTest_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(DewJunkieTest_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(DewJunkieTest_global_options)
  if(DewJunkieTest_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    DewJunkieTest_enable_ipo()
  endif()

  DewJunkieTest_supports_sanitizers()

  if(DewJunkieTest_ENABLE_HARDENING AND DewJunkieTest_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR DewJunkieTest_ENABLE_SANITIZER_UNDEFINED
       OR DewJunkieTest_ENABLE_SANITIZER_ADDRESS
       OR DewJunkieTest_ENABLE_SANITIZER_THREAD
       OR DewJunkieTest_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${DewJunkieTest_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${DewJunkieTest_ENABLE_SANITIZER_UNDEFINED}")
    DewJunkieTest_enable_hardening(DewJunkieTest_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(DewJunkieTest_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(DewJunkieTest_warnings INTERFACE)
  add_library(DewJunkieTest_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  DewJunkieTest_set_project_warnings(
    DewJunkieTest_warnings
    ${DewJunkieTest_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(DewJunkieTest_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(DewJunkieTest_options)
  endif()

  include(cmake/Sanitizers.cmake)
  DewJunkieTest_enable_sanitizers(
    DewJunkieTest_options
    ${DewJunkieTest_ENABLE_SANITIZER_ADDRESS}
    ${DewJunkieTest_ENABLE_SANITIZER_LEAK}
    ${DewJunkieTest_ENABLE_SANITIZER_UNDEFINED}
    ${DewJunkieTest_ENABLE_SANITIZER_THREAD}
    ${DewJunkieTest_ENABLE_SANITIZER_MEMORY})

  set_target_properties(DewJunkieTest_options PROPERTIES UNITY_BUILD ${DewJunkieTest_ENABLE_UNITY_BUILD})

  if(DewJunkieTest_ENABLE_PCH)
    target_precompile_headers(
      DewJunkieTest_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(DewJunkieTest_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    DewJunkieTest_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(DewJunkieTest_ENABLE_CLANG_TIDY)
    DewJunkieTest_enable_clang_tidy(DewJunkieTest_options ${DewJunkieTest_WARNINGS_AS_ERRORS})
  endif()

  if(DewJunkieTest_ENABLE_CPPCHECK)
    DewJunkieTest_enable_cppcheck(${DewJunkieTest_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(DewJunkieTest_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    DewJunkieTest_enable_coverage(DewJunkieTest_options)
  endif()

  if(DewJunkieTest_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(DewJunkieTest_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(DewJunkieTest_ENABLE_HARDENING AND NOT DewJunkieTest_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR DewJunkieTest_ENABLE_SANITIZER_UNDEFINED
       OR DewJunkieTest_ENABLE_SANITIZER_ADDRESS
       OR DewJunkieTest_ENABLE_SANITIZER_THREAD
       OR DewJunkieTest_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    DewJunkieTest_enable_hardening(DewJunkieTest_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
