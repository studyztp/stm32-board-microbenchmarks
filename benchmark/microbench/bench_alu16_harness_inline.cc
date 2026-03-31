// alu16 benchmark — inline asm through the EntoBench harness.
// The lambda is inlined into the harness rep loop: no blx overhead.

#include <ento-bench/harness.h>
#include <ento-bench/bench_config.h>
#include <ento-mcu/clk_util.h>
#include <ento-mcu/systick_config.h>

extern "C" void initialise_monitor_handles(void);

int main()
{
    initialise_monitor_handles();

    sys_clk_cfg();
    SysTick_Setup();
    __enable_irq();

    ENTO_BENCH_SETUP();
    ENTO_BENCH_PRINT_CONFIG();

    auto kernel = []() __attribute__((always_inline)) {
        asm volatile(
            ".balign 16           \n"
            ".rept 25             \n"
            "adds r0, r0, r1     \n"
            "subs r2, r2, r3     \n"
            "eors r0, r0, r2     \n"
            "orrs r2, r2, r3     \n"
            ".endr                \n"
            :
            :
            : "r0", "r1", "r2", "r3", "memory"
        );
    };
    auto problem = EntoBench::make_basic_problem(kernel);

    ENTO_BENCH_HARNESS_TYPE(decltype(problem));
    BenchHarness harness(problem, "bench_alu16_harness_inline");
    harness.run();

    exit(0);
    return 0;
}
