#ifndef KERNELS_INLINE_H
#define KERNELS_INLINE_H

// Inline-asm microbenchmark kernels.
// Each is always_inline so the compiler embeds them directly in the harness
// loop — no function pointer indirection, no blx overhead.

#define KERNEL_INLINE static inline void __attribute__((always_inline))

// =========================================================================
// Compute benchmarks
// =========================================================================

KERNEL_INLINE bench_nop_kernel() {
    asm volatile(
        ".rept 100 \n"
        "nop       \n"
        ".endr     \n"
        ::: "memory"
    );
}

KERNEL_INLINE bench_nop_loop_kernel() {
    asm volatile(
        "mov r0, #100       \n"
        "1:                 \n"
        "nop                \n"
        "subs r0, r0, #1   \n"
        "bne 1b             \n"
        ::: "r0", "memory"
    );
}

KERNEL_INLINE bench_alu_kernel() {
    asm volatile(
        ".rept 25            \n"
        "add.w r0, r0, r1   \n"
        "sub.w r2, r2, r3   \n"
        "and.w r0, r0, r2   \n"
        "orr.w r2, r1, r3   \n"
        ".endr               \n"
        ::: "r0", "r1", "r2", "r3", "memory"
    );
}

KERNEL_INLINE bench_alu16_kernel() {
    asm volatile(
        ".rept 25            \n"
        "adds r0, r0, r1    \n"
        "subs r2, r2, r3    \n"
        "eors r0, r0, r2    \n"
        "orrs r2, r2, r3    \n"
        ".endr               \n"
        ::: "r0", "r1", "r2", "r3", "memory"
    );
}

KERNEL_INLINE bench_alu16_loop_kernel() {
    asm volatile(
        "movs r0, #1         \n"
        "movs r1, #2         \n"
        "movs r2, #3         \n"
        "movs r3, #4         \n"
        "movs r6, #100       \n"
        "1:                  \n"
        "adds r4, r0, r1    \n"
        "subs r5, r2, r3    \n"
        "eors r4, r4, r2    \n"
        "orrs r5, r5, r3    \n"
        "subs r6, r6, #1    \n"
        "bne 1b              \n"
        ::: "r0", "r1", "r2", "r3", "r4", "r5", "r6", "memory"
    );
}

KERNEL_INLINE bench_mul_kernel() {
    asm volatile(
        "mov r0, #7          \n"
        "mov r1, #13         \n"
        ".rept 100           \n"
        "mul.w r2, r0, r1   \n"
        ".endr               \n"
        ::: "r0", "r1", "r2", "memory"
    );
}

KERNEL_INLINE bench_div_kernel() {
    asm volatile(
        "ldr r0, =0x7FFFFFFF \n"
        "mov r1, #1          \n"
        ".rept 20            \n"
        "sdiv r2, r0, r1    \n"
        ".endr               \n"
        ::: "r0", "r1", "r2", "memory"
    );
}

KERNEL_INLINE bench_div_short_kernel() {
    asm volatile(
        "mov r0, #15         \n"
        "mov r1, #3          \n"
        ".rept 20            \n"
        "sdiv r2, r0, r1    \n"
        ".endr               \n"
        ::: "r0", "r1", "r2", "memory"
    );
}

KERNEL_INLINE bench_pushpop_kernel() {
    asm volatile(
        "mov r0, #0          \n"
        "mov r1, #1          \n"
        "mov r2, #2          \n"
        "mov r3, #3          \n"
        "mov r4, #4          \n"
        "mov r5, #5          \n"
        "mov r6, #6          \n"
        "mov r7, #7          \n"
        "push {r0-r7}        \n"
        "pop  {r0-r7}        \n"
        "push {r0-r3}        \n"
        "pop  {r0-r3}        \n"
        "push {r4-r7}        \n"
        "pop  {r4-r7}        \n"
        ::: "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "memory"
    );
}

KERNEL_INLINE bench_fpu_kernel() {
    asm volatile(
        "vmov s0, #1.0       \n"
        "vmov s1, #2.0       \n"
        ".rept 20            \n"
        "vadd.f32 s2, s0, s1 \n"
        "vmul.f32 s3, s0, s1 \n"
        ".endr               \n"
        ".rept 5             \n"
        "vdiv.f32 s4, s0, s1 \n"
        ".endr               \n"
        ::: "s0", "s1", "s2", "s3", "s4", "memory"
    );
}

KERNEL_INLINE bench_dmb_kernel() {
    asm volatile(
        ".rept 20  \n"
        "dmb sy    \n"
        ".endr     \n"
        ".rept 20  \n"
        "dsb sy    \n"
        ".endr     \n"
        ".rept 10  \n"
        "isb sy    \n"
        ".endr     \n"
        ::: "memory"
    );
}

KERNEL_INLINE bench_mixed_width_kernel() {
    asm volatile(
        ".rept 25            \n"
        "nop                 \n"
        "and.w r0, r0, r2   \n"
        "nop                 \n"
        "orr.w r2, r1, r3   \n"
        ".endr               \n"
        ::: "r0", "r1", "r2", "r3", "memory"
    );
}

// =========================================================================
// Memory access benchmarks
// =========================================================================

KERNEL_INLINE bench_load_kernel() {
    asm volatile(
        "ldr r6, =0x20000200  \n"
        ".rept 50             \n"
        "ldr r0, [r6]        \n"
        ".endr                \n"
        ::: "r0", "r6", "memory"
    );
}

KERNEL_INLINE bench_load_dep_kernel() {
    asm volatile(
        "ldr r6, =0x20000200  \n"
        "str r6, [r6]        \n"
        ".rept 50             \n"
        "ldr r6, [r6]        \n"
        ".endr                \n"
        ::: "r6", "memory"
    );
}

KERNEL_INLINE bench_store_kernel() {
    asm volatile(
        "ldr r6, =0x20000200  \n"
        "mov r0, #42         \n"
        ".rept 50             \n"
        "str r0, [r6]        \n"
        ".endr                \n"
        ::: "r0", "r6", "memory"
    );
}

KERNEL_INLINE bench_store_burst_kernel() {
    asm volatile(
        "ldr r6, =0x20000200  \n"
        "mov r0, #42         \n"
        ".set OFF, 0          \n"
        ".rept 50             \n"
        "str r0, [r6, #OFF]  \n"
        ".set OFF, OFF + 4    \n"
        ".endr                \n"
        ::: "r0", "r6", "memory"
    );
}

KERNEL_INLINE bench_ldr_literal_kernel() {
    asm volatile(
        ".irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24 \n"
        "ldr r0, =0xDEAD0000 + \\i \n"
        "ldr r1, =0xBEEF0000 + \\i \n"
        ".endr                \n"
        ::: "r0", "r1", "memory"
    );
}

KERNEL_INLINE bench_ccm_sram_kernel() {
    asm volatile(
        "ldr r6, =0x10000200  \n"
        "mov r0, #42         \n"
        "str r0, [r6]        \n"
        ".rept 50             \n"
        "ldr r0, [r6]        \n"
        ".endr                \n"
        ".rept 50             \n"
        "str r0, [r6]        \n"
        ".endr                \n"
        ::: "r0", "r6", "memory"
    );
}

KERNEL_INLINE bench_scs_read_kernel() {
    asm volatile(
        "ldr r6, =0xE000E000  \n"
        ".rept 25             \n"
        "ldr r0, [r6, #0x18] \n"
        "ldr r1, [r6, #0x10] \n"
        ".endr                \n"
        ::: "r0", "r1", "r6", "memory"
    );
}

KERNEL_INLINE bench_scs_store_kernel() {
    asm volatile(
        "ldr r6, =0xE000E000  \n"
        "mov r0, #0          \n"
        ".rept 25             \n"
        "str r0, [r6, #0x18] \n"
        "str r0, [r6, #0x280]\n"
        ".endr                \n"
        ::: "r0", "r6", "memory"
    );
}

// =========================================================================
// Cache/prefetch benchmarks
// =========================================================================

KERNEL_INLINE bench_art_prefetch_kernel() {
    asm volatile(
        ".balign 8           \n"
        ".rept 200           \n"
        "nop                 \n"
        ".endr               \n"
        ::: "memory"
    );
}

// Too large for inline asm (branch offset errors). Defined in kernel_icache_miss.S.
extern "C" void bench_icache_miss_asm(void);
KERNEL_INLINE bench_icache_miss_kernel() {
    bench_icache_miss_asm();
}

// =========================================================================
// Branch prediction benchmarks
// =========================================================================

KERNEL_INLINE bench_branch_kernel() {
    asm volatile(
        "mov r0, #100        \n"
        "1:                  \n"
        "subs r0, r0, #1    \n"
        "bne 1b              \n"
        ::: "r0", "memory"
    );
}

KERNEL_INLINE bench_bp_tight_kernel() {
    asm volatile(
        "mov r0, #200        \n"
        "1:                  \n"
        "subs r0, r0, #1    \n"
        "bne 1b              \n"
        ::: "r0", "memory"
    );
}

KERNEL_INLINE bench_bp_long_body_kernel() {
    asm volatile(
        "mov r0, #100        \n"
        "1:                  \n"
        ".rept 8             \n"
        "nop                 \n"
        ".endr               \n"
        "subs r0, r0, #1    \n"
        "bne 1b              \n"
        ::: "r0", "memory"
    );
}

KERNEL_INLINE bench_bp_forward_kernel() {
    asm volatile(
        "mov r0, #0          \n"
        "mov r1, #100        \n"
        "1:                  \n"
        "cmp r0, r0          \n"
        "beq 2f              \n"
        "nop                 \n"
        "nop                 \n"
        "2:                  \n"
        "subs r1, r1, #1    \n"
        "bne 1b              \n"
        ::: "r0", "r1", "memory"
    );
}

KERNEL_INLINE bench_bp_alternating_kernel() {
    asm volatile(
        "mov r0, #200        \n"
        "1:                  \n"
        "ands r1, r0, #1    \n"
        "bne 2f              \n"
        "nop                 \n"
        "2:                  \n"
        "subs r0, r0, #1    \n"
        "bne 1b              \n"
        ::: "r0", "r1", "memory"
    );
}

KERNEL_INLINE bench_bp_nested_kernel() {
    asm volatile(
        "mov r0, #20         \n"
        "1:                  \n"
        "mov r1, #10         \n"
        "2:                  \n"
        "subs r1, r1, #1    \n"
        "bne 2b              \n"
        "subs r0, r0, #1    \n"
        "bne 1b              \n"
        ::: "r0", "r1", "memory"
    );
}

KERNEL_INLINE bench_bp_align_kernel() {
    asm volatile(
        "mov r0, #100        \n"
        ".balign 4           \n"
        "1:                  \n"
        "subs r0, r0, #1    \n"
        "bne 1b              \n"
        "nop                 \n"
        "mov r0, #100        \n"
        "2:                  \n"
        "subs r0, r0, #1    \n"
        "bne 2b              \n"
        "nop                 \n"
        "mov r0, #100        \n"
        "3:                  \n"
        "sub.w r0, r0, #1   \n"
        "bne 3b              \n"
        ::: "r0", "memory"
    );
}

#undef KERNEL_INLINE
#endif // KERNELS_INLINE_H
