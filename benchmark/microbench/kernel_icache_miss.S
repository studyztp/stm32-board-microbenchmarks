    .syntax unified
    .thumb

/* bench_icache_miss: 4 iterations of 2KB NOP sled (I-cache capacity miss) */
    .global bench_icache_miss_asm
    .thumb_func
    .type bench_icache_miss_asm, %function
bench_icache_miss_asm:
    mov r0, #0
1:
    .rept 1024
    nop
    .endr
    adds r0, r0, #1
    cmp r0, #4
    bne 1b
    bx lr
