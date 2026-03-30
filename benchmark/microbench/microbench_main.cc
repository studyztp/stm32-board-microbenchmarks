// Parametric microbenchmark main — compiled once per benchmark with:
//   -DKERNEL_FN=bench_<name>_kernel  (function symbol from kernels_inline.h)
//   -DKERNEL_NAME=bench_<name>       (display name)

#include <ento-bench/harness.h>
#include <ento-bench/bench_config.h>
#include <ento-mcu/clk_util.h>
#include <ento-mcu/systick_config.h>

#include "kernels_inline.h"

#define XSTR(x) #x
#define STR(x) XSTR(x)

extern "C" void initialise_monitor_handles(void);

int main()
{
    initialise_monitor_handles();

    // Configure max clock rate and flash latency
    sys_clk_cfg();
    SysTick_Setup();
    __enable_irq();

    ENTO_BENCH_SETUP();
    ENTO_BENCH_PRINT_CONFIG();

    auto problem = EntoBench::make_basic_problem([]() __attribute__((always_inline)) {
        KERNEL_FN();
    });
    ENTO_BENCH_HARNESS_TYPE(decltype(problem));
    BenchHarness harness(problem, STR(KERNEL_NAME));
    harness.run();

    exit(0);
    return 0;
}
