/*
 * gem5 pseudo-ops via M-profile semihosting (BKPT #0xAB).
 *
 * ARM semihosting ABI (AArch32):
 *   R0 = operation code
 *   R1 = pointer to parameter block (array of 32-bit words)
 *
 * For gem5 pseudo-ops:
 *   R0 = 0x100 (SYS_GEM5_PSEUDO_OP)
 *   R1 = &param_block
 *   param_block[0] = encoded_func  (func_code << 8)
 *   param_block[1..] = arguments
 *
 * Reference: gem5 src/arch/arm/semihosting.hh (SYS_GEM5_PSEUDO_OP = 0x100)
 *            gem5 src/sim/pseudo_inst.hh (decodeAddrOffset: func = bits[15:8])
 *            gem5 include/gem5/asm/generic/m5ops.h (op codes)
 *            gem5 src/arch/arm/m_insts.hh (BkptSemiMProfile)
 */

#ifndef GEM5_M5OPS_SEMI_H
#define GEM5_M5OPS_SEMI_H

#include <cstdint>
#include <gem5/asm/generic/m5ops.h>

/* SYS_GEM5_PSEUDO_OP semihosting operation code */
#define SYS_GEM5_PSEUDO_OP 0x100

/*
 * Issue a gem5 pseudo-op via M-profile semihosting.
 *
 * Uses a static parameter block (like arm64 m5op_semi.S) to avoid
 * compiler FP-register optimizations that can cause "co-processor
 * offset out of range" errors with large kernels.
 */
__attribute__((noinline))
static uint32_t
m5_semi_call(uint8_t func, uint32_t arg0, uint32_t arg1)
{
    static volatile uint32_t param_block[3];
    param_block[0] = (uint32_t)func << 8;  /* decodeAddrOffset: bits[15:8] */
    param_block[1] = arg0;
    param_block[2] = arg1;

    register uint32_t r0 __asm__("r0") = SYS_GEM5_PSEUDO_OP;
    register uint32_t r1 __asm__("r1") = (uint32_t)&param_block[0];

    __asm__ volatile(
        "bkpt #0xab"
        : "+r"(r0)
        : "r"(r1)
        : "memory"
    );

    return r0;
}

static inline void m5_reset_stats(uint32_t delay = 0, uint32_t period = 0)
{
    m5_semi_call(M5OP_RESET_STATS, delay, period);
}

static inline void m5_dump_stats(uint32_t delay = 0, uint32_t period = 0)
{
    m5_semi_call(M5OP_DUMP_STATS, delay, period);
}

static inline void m5_dump_reset_stats(uint32_t delay = 0, uint32_t period = 0)
{
    m5_semi_call(M5OP_DUMP_RESET_STATS, delay, period);
}

static inline void m5_work_begin(uint32_t workid = 0, uint32_t threadid = 0)
{
    m5_semi_call(M5OP_WORK_BEGIN, workid, threadid);
}

static inline void m5_work_end(uint32_t workid = 0, uint32_t threadid = 0)
{
    m5_semi_call(M5OP_WORK_END, workid, threadid);
}

static inline void m5_exit(uint32_t code = 0)
{
    m5_semi_call(M5OP_EXIT, code, 0);
}

#endif /* GEM5_M5OPS_SEMI_H */
