# =============================================================================
# STM32G474RE Microbenchmarks — EntoBench Integration
# =============================================================================
include(${CMAKE_SOURCE_DIR}/entobench_helpers.cmake)

if(NOT STM32_BUILD)
  message(STATUS "Microbenchmarks require STM32_BUILD — skipping")
  return()
endif()

if(NOT DEFINED MICROBENCH_CONFIG_FILE)
  set(MICROBENCH_CONFIG_FILE "configs/microbench.json")
endif()

# gem5 semihosting ROI: uses BKPT #0xAB to call gem5 pseudo-ops
option(GEM5_SEMIHOSTING "Use gem5 semihosting for ROI markers instead of DWT counters" OFF)
# gem5 simulation mode: skips RCC/PWR/Flash/SysTick init that gem5 doesn't model
option(GEM5_SIM "Target gem5 simulation (skip hardware peripheral init)" OFF)

# GEM5_SEMIHOSTING implies GEM5_SIM
if(GEM5_SEMIHOSTING AND NOT GEM5_SIM)
  set(GEM5_SIM ON CACHE BOOL "Implied by GEM5_SEMIHOSTING" FORCE)
endif()

if(GEM5_SIM)
  add_definitions(-DGEM5_SIM=1)
  message(STATUS "gem5 simulation mode — peripheral init skipped")
endif()
if(GEM5_SEMIHOSTING)
  add_definitions(-DGEM5_SEMIHOSTING=1)
  message(STATUS "gem5 semihosting ROI enabled — DWT counters disabled")
endif()

# Libraries needed by all microbenchmarks
set(MODULES
  bench
  ento-mcu-semihosted
  CMSIS::STM32::${STM_PRODUCT}
)

# =============================================================================
# Define all simple (non-exception) microbenchmarks
# =============================================================================
set(MICROBENCHMARKS
    # --- Compute ---
    nop
    alu
    alu16
    mul
    div
    div_short
    pushpop
    fpu
    dmb
    mixed_width
    # --- Memory ---
    load
    load_dep
    store
    store_burst
    ldr_literal
    ccm_sram
    scs_read
    scs_store
    # --- Cache/Prefetch ---
    art_prefetch
    icache_miss
    # --- Branch/Branch Prediction ---
    branch
    bp_tight
    bp_long_body
    bp_forward
    bp_alternating
    bp_nested
    bp_align
)

# Track all targets for group operations
set(BENCH_TARGETS)

foreach(bench ${MICROBENCHMARKS})
    set(TARGET_NAME bench-${bench})

    set(EXTRA_SOURCES "")
    if(bench STREQUAL "icache_miss")
      set(EXTRA_SOURCES kernel_icache_miss.S)
    endif()

    add_benchmark(${TARGET_NAME}
      SOURCES microbench_main.cc ${EXTRA_SOURCES}
      LIBRARIES ${MODULES}
    )

    target_compile_definitions(${TARGET_NAME} PRIVATE
      KERNEL_FN=bench_${bench}_kernel
      KERNEL_NAME=bench_${bench}
    )

    target_include_directories(${TARGET_NAME} PRIVATE
      ${EIGEN_DIR}
      ${CMAKE_CURRENT_SOURCE_DIR}/include
      ${CMAKE_CURRENT_SOURCE_DIR}
    )

    list(APPEND BENCH_TARGETS ${TARGET_NAME})
endforeach()

# =============================================================================
# Inline-asm harness benchmarks (lambda inlined into harness loop)
# =============================================================================
set(INLINE_HARNESS_BENCHMARKS
    bench-nop-harness-inline
    bench-alu16-harness-inline
)

foreach(tgt ${INLINE_HARNESS_BENCHMARKS})
    string(REPLACE "-" "_" src_name ${tgt})
    add_benchmark(${tgt}
      SOURCES ${src_name}.cc
      LIBRARIES ${MODULES}
    )
    target_include_directories(${tgt} PRIVATE
      ${EIGEN_DIR}
      ${CMAKE_CURRENT_SOURCE_DIR}/include
      ${CMAKE_CURRENT_SOURCE_DIR}
    )
    list(APPEND BENCH_TARGETS ${tgt})
endforeach()

# =============================================================================
# Inline-asm benchmarks (ROI inside function, compiler-managed layout)
# =============================================================================
add_benchmark(bench-inline
  SOURCES inline_benchmarks.cc
  LIBRARIES ${MODULES}
)
target_include_directories(bench-inline PRIVATE
  ${EIGEN_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}
)
list(APPEND BENCH_TARGETS bench-inline)

# =============================================================================
# Configure benchmark group from JSON (must be after all targets are added)
# =============================================================================
add_configured_benchmark_group_with_target_configs("microbench"
  TARGETS ${BENCH_TARGETS}
  CONFIG_FILE "${CMAKE_SOURCE_DIR}/${MICROBENCH_CONFIG_FILE}"
)

# =============================================================================
# STM32 flash/debug targets (if OpenOCD is available)
# =============================================================================
if(OPENOCD_EXECUTABLE AND OPENOCD_INTERFACE)
  add_stm32_targets("${BENCH_TARGETS}")
endif()

# =============================================================================
# Summary
# =============================================================================
list(LENGTH BENCH_TARGETS BENCH_COUNT)
message(STATUS "Configured ${BENCH_COUNT} microbenchmark targets")
