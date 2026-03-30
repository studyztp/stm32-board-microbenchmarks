/*
 * Microbenchmark kernel functions for EntoBench harness.
 *
 * Each kernel contains ONLY the measured instructions from the original
 * standalone benchmark. No vector tables, no timing markers, no warmup.
 * The EntoBench harness handles DWT cycle counting and warmup.
 *
 * Calling convention: ARM AAPCS (callee-saved r4-r11 preserved).
 * Each kernel returns via bx lr.
 */

    .syntax unified
    .thumb

/* =========================================================================
 * Compute benchmarks
 * ========================================================================= */

/* bench_nop: 100 NOPs — pipeline throughput baseline */
    .global bench_nop_kernel
    .thumb_func
    .type bench_nop_kernel, %function
bench_nop_kernel:
    .rept 100
    nop
    .endr
    bx lr

/* bench_nop_loop: 100 NOPs via loop (stays in ART cache) */
    .global bench_nop_loop_kernel
    .thumb_func
    .type bench_nop_loop_kernel, %function
bench_nop_loop_kernel:
    mov r0, #100
.Lnop_loop:
    nop
    subs r0, r0, #1
    bne .Lnop_loop
    bx lr

/* bench_alu16_loop: 100 iterations of 4 ALU ops (16-bit, loop) */
    .global bench_alu16_loop_kernel
    .thumb_func
    .type bench_alu16_loop_kernel, %function
bench_alu16_loop_kernel:
    push {r4, r5, r6}
    movs r0, #1
    movs r1, #2
    movs r2, #3
    movs r3, #4
    movs r6, #100
.Lalu16_loop:
    adds r4, r0, r1
    subs r5, r2, r3
    eors r4, r4, r2
    orrs r5, r5, r3
    subs r6, r6, #1
    bne .Lalu16_loop
    pop {r4, r5, r6}
    bx lr

/* bench_alu: 100 ALU ops (ADD/SUB/AND/ORR, 32-bit encodings) */
    .global bench_alu_kernel
    .thumb_func
    .type bench_alu_kernel, %function
bench_alu_kernel:
    push {r4, r5}
    mov r0, #1
    mov r1, #2
    mov r2, #3
    mov r3, #4
    .rept 25
    add   r4, r0, r1
    sub   r5, r2, r3
    and.w r4, r0, r2
    orr.w r5, r1, r3
    .endr
    pop {r4, r5}
    bx lr

/* bench_alu16: 100 ALU ops (16-bit Thumb encodings) */
    .global bench_alu16_kernel
    .thumb_func
    .type bench_alu16_kernel, %function
bench_alu16_kernel:
    push {r4, r5}
    movs r0, #1
    movs r1, #2
    movs r2, #3
    movs r3, #4
    .rept 25
    adds r4, r0, r1
    subs r5, r2, r3
    eors r4, r4, r2
    orrs r5, r5, r3
    .endr
    pop {r4, r5}
    bx lr

/* bench_mul: 100 MUL.W (32x32 multiply) */
    .global bench_mul_kernel
    .thumb_func
    .type bench_mul_kernel, %function
bench_mul_kernel:
    mov r0, #7
    mov r1, #13
    .rept 100
    mul.w r2, r0, r1
    .endr
    bx lr

/* bench_div: 20 SDIV (worst-case: 0x7FFFFFFF / 1) */
    .global bench_div_kernel
    .thumb_func
    .type bench_div_kernel, %function
bench_div_kernel:
    ldr r0, =0x7FFFFFFF
    mov r1, #1
    .rept 20
    sdiv r2, r0, r1
    .endr
    bx lr

/* bench_div_short: 20 SDIV (best-case: 15 / 3) */
    .global bench_div_short_kernel
    .thumb_func
    .type bench_div_short_kernel, %function
bench_div_short_kernel:
    mov r0, #15
    mov r1, #3
    .rept 20
    sdiv r2, r0, r1
    .endr
    bx lr

/* bench_pushpop: multi-register PUSH/POP */
    .global bench_pushpop_kernel
    .thumb_func
    .type bench_pushpop_kernel, %function
bench_pushpop_kernel:
    push {r4-r7, lr}
    mov r0, #0
    mov r1, #1
    mov r2, #2
    mov r3, #3
    mov r4, #4
    mov r5, #5
    push {r0-r7, lr}
    pop  {r0-r7, lr}
    push {r0-r3}
    pop  {r0-r3}
    pop {r4-r7, pc}

/* bench_fpu: FP add/mul/div throughput */
    .global bench_fpu_kernel
    .thumb_func
    .type bench_fpu_kernel, %function
bench_fpu_kernel:
    vmov s0, #1.0
    vmov s1, #2.0
    .rept 20
    vadd.f32 s2, s0, s1
    vmul.f32 s3, s0, s1
    .endr
    .rept 5
    vdiv.f32 s4, s0, s1
    .endr
    bx lr

/* bench_dmb: memory barrier latency (DMB/DSB/ISB) */
    .global bench_dmb_kernel
    .thumb_func
    .type bench_dmb_kernel, %function
bench_dmb_kernel:
    .rept 20
    dmb sy
    .endr
    .rept 20
    dsb sy
    .endr
    .rept 10
    isb sy
    .endr
    bx lr

/* bench_mixed_width: alternating 16-bit and 32-bit instructions */
    .global bench_mixed_width_kernel
    .thumb_func
    .type bench_mixed_width_kernel, %function
bench_mixed_width_kernel:
    push {r4, r5}
    movs r0, #1
    movs r1, #2
    movs r2, #3
    movs r3, #4
    .rept 25
    nop
    and.w r4, r0, r2
    nop
    orr.w r5, r1, r3
    .endr
    pop {r4, r5}
    bx lr

/* =========================================================================
 * Memory access benchmarks
 * ========================================================================= */

/* bench_load: 50 independent loads from SRAM */
    .global bench_load_kernel
    .thumb_func
    .type bench_load_kernel, %function
bench_load_kernel:
    push {r6}
    ldr r6, =0x20000200
    .rept 50
    ldr r0, [r6]
    .endr
    pop {r6}
    bx lr

/* bench_load_dep: 50 dependent loads (serialized chain) */
    .global bench_load_dep_kernel
    .thumb_func
    .type bench_load_dep_kernel, %function
bench_load_dep_kernel:
    push {r6}
    ldr r6, =0x20000200
    str r6, [r6]             /* self-referencing pointer */
    .rept 50
    ldr r6, [r6]
    .endr
    pop {r6}
    bx lr

/* bench_store: 50 stores to same SRAM address */
    .global bench_store_kernel
    .thumb_func
    .type bench_store_kernel, %function
bench_store_kernel:
    push {r6}
    ldr r6, =0x20000200
    mov r0, #42
    .rept 50
    str r0, [r6]
    .endr
    pop {r6}
    bx lr

/* bench_store_burst: 50 stores to consecutive SRAM addresses */
    .global bench_store_burst_kernel
    .thumb_func
    .type bench_store_burst_kernel, %function
bench_store_burst_kernel:
    push {r6}
    ldr r6, =0x20000200
    mov r0, #42
    .set OFF, 0
    .rept 50
    str r0, [r6, #OFF]
    .set OFF, OFF + 4
    .endr
    pop {r6}
    bx lr

/* bench_ldr_literal: 50 PC-relative literal pool loads */
    .global bench_ldr_literal_kernel
    .thumb_func
    .type bench_ldr_literal_kernel, %function
bench_ldr_literal_kernel:
    .irp i, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24
    ldr r0, =0xDEAD0000 + \i
    ldr r1, =0xBEEF0000 + \i
    .endr
    bx lr

/* bench_ccm_sram: 50 loads + 50 stores to CCM SRAM (0x10000000) */
    .global bench_ccm_sram_kernel
    .thumb_func
    .type bench_ccm_sram_kernel, %function
bench_ccm_sram_kernel:
    push {r6}
    ldr r6, =0x10000200
    mov r0, #42
    str r0, [r6]
    .rept 50
    ldr r0, [r6]
    .endr
    .rept 50
    str r0, [r6]
    .endr
    pop {r6}
    bx lr

/* bench_scs_read: 50 System Control Space register reads */
    .global bench_scs_read_kernel
    .thumb_func
    .type bench_scs_read_kernel, %function
bench_scs_read_kernel:
    push {r6}
    ldr r6, =0xE000E000      /* SCS_BASE */
    .rept 25
    ldr r0, [r6, #0x18]      /* SYST_CVR */
    ldr r1, [r6, #0x10]      /* SYST_CSR */
    .endr
    pop {r6}
    bx lr

/* bench_scs_store: 50 System Control Space register writes */
    .global bench_scs_store_kernel
    .thumb_func
    .type bench_scs_store_kernel, %function
bench_scs_store_kernel:
    push {r6}
    ldr r6, =0xE000E000      /* SCS_BASE */
    mov r0, #0
    .rept 25
    str r0, [r6, #0x18]      /* SYST_CVR */
    str r0, [r6, #0x280]     /* NVIC_ICPR0 */
    .endr
    pop {r6}
    bx lr

/* =========================================================================
 * Cache/prefetch benchmarks
 * ========================================================================= */

/* bench_art_prefetch: 200 NOPs after 8-byte alignment (ART prefetch) */
    .global bench_art_prefetch_kernel
    .thumb_func
    .type bench_art_prefetch_kernel, %function
bench_art_prefetch_kernel:
    .balign 8
    .rept 200
    nop
    .endr
    bx lr

/* bench_icache_miss: 4 iterations of 2KB NOP sled (I-cache capacity miss) */
    .global bench_icache_miss_kernel
    .thumb_func
    .type bench_icache_miss_kernel, %function
bench_icache_miss_kernel:
    push {r4}
    mov r4, #0
.Licm_outer:
    .rept 1024
    nop
    .endr
    adds r4, r4, #1
    cmp r4, #4
    bne .Licm_outer
    pop {r4}
    bx lr

/* =========================================================================
 * Branch prediction benchmarks
 * ========================================================================= */

/* bench_branch: 100-iteration tight backward loop */
    .global bench_branch_kernel
    .thumb_func
    .type bench_branch_kernel, %function
bench_branch_kernel:
    mov r0, #100
.Lbr_loop:
    subs r0, r0, #1
    bne .Lbr_loop
    bx lr

/* bench_bp_tight: 200-iteration tight backward loop */
    .global bench_bp_tight_kernel
    .thumb_func
    .type bench_bp_tight_kernel, %function
bench_bp_tight_kernel:
    mov r0, #200
.Lbpt_loop:
    subs r0, r0, #1
    bne .Lbpt_loop
    bx lr

/* bench_bp_long_body: 100-iteration loop with 8 NOPs in body */
    .global bench_bp_long_body_kernel
    .thumb_func
    .type bench_bp_long_body_kernel, %function
bench_bp_long_body_kernel:
    mov r0, #100
.Lbplb_loop:
    .rept 8
    nop
    .endr
    subs r0, r0, #1
    bne .Lbplb_loop
    bx lr

/* bench_bp_forward: 100-iteration forward branch (CMP+BEQ always taken) */
    .global bench_bp_forward_kernel
    .thumb_func
    .type bench_bp_forward_kernel, %function
bench_bp_forward_kernel:
    push {r4, r5}
    mov r4, #0
    mov r5, #100
.Lbpf_loop:
    cmp r4, r4
    beq .Lbpf_skip
    nop
    nop
.Lbpf_skip:
    subs r5, r5, #1
    bne .Lbpf_loop
    pop {r4, r5}
    bx lr

/* bench_bp_alternating: 200-iteration alternating taken/not-taken */
    .global bench_bp_alternating_kernel
    .thumb_func
    .type bench_bp_alternating_kernel, %function
bench_bp_alternating_kernel:
    mov r0, #200
.Lbpa_loop:
    ands r1, r0, #1
    bne .Lbpa_skip
    nop
.Lbpa_skip:
    subs r0, r0, #1
    bne .Lbpa_loop
    bx lr

/* bench_bp_nested: nested loops (20 outer x 10 inner) */
    .global bench_bp_nested_kernel
    .thumb_func
    .type bench_bp_nested_kernel, %function
bench_bp_nested_kernel:
    push {r4, r5}
    mov r4, #20
.Lbpn_outer:
    mov r5, #10
.Lbpn_inner:
    subs r5, r5, #1
    bne .Lbpn_inner
    subs r4, r4, #1
    bne .Lbpn_outer
    pop {r4, r5}
    bx lr

/* bench_bp_align: branch target alignment effects (3 parts x 100 iterations) */
    .global bench_bp_align_kernel
    .thumb_func
    .type bench_bp_align_kernel, %function
bench_bp_align_kernel:
    /* Part A: target at 4-byte aligned address */
    mov r0, #100
    .balign 4
.Lbpal_loopA:
    subs r0, r0, #1
    bne .Lbpal_loopA

    /* Part B: target at halfword boundary */
    nop
    mov r0, #100
.Lbpal_loopB:
    subs r0, r0, #1
    bne .Lbpal_loopB

    /* Part C: 32-bit instruction at halfword boundary */
    nop
    mov r0, #100
.Lbpal_loopC:
    sub.w r0, r0, #1
    bne .Lbpal_loopC

    bx lr
