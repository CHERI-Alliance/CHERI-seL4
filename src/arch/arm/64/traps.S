/*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 * Copyright 2024-2025, Capabilities Limited
 * CHERI support contributed by Capabilities Limited was developed by Hesham Almatary
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include <config.h>
#include <machine/assembler.h>
#include <arch/api/syscall.h>
#include <arch/machine/hardware.h>
#include <arch/machine/registerset.h>

#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT

#define ESR     esr_el2
#define SPSR    spsr_el2
#define TPIDR   tpidr_el2
#define ELR     REGN(elr_el2)

#else

#define ESR     esr_el1
#define SPSR    spsr_el1
#define TPIDR   tpidr_el1
#define ELR     REGN(elr_el1)

#endif


.macro lsp_i _tmp
    mrs     \_tmp, TPIDR
#ifdef CONFIG_ENABLE_SMP_SUPPORT
    bic     \_tmp, \_tmp, #0xfff
#endif
    mov     sp, \_tmp
.endm

.macro ventry label
.align 7
    b       \label
.endm

#ifdef CONFIG_DEBUG_BUILD
.macro ventry_invalid
.align 7
    /* compute vect_offset argument */
    adr     x0, .
    adr     x19, arm_vector_table
    sub     x0, x0, x19
    b       invalid_vector_entry
.endm
#else
.macro ventry_invalid
    ventry invalid_vector_entry
.endm
#endif

#ifdef CONFIG_AARCH64_SERROR_IGNORE
.macro ventry_serror
.align 7
    eret
.endm
#else
.macro ventry_serror
    ventry_invalid
.endm
#endif

.section .vectors, "ax"

/* The layout of this table are specified in Table D1-7, 'Vector offsets from
 * vector table base address' of ARM DDI 0487B.b ID092517.
 * Each vector entry has 128-byte alignment, and so supports 32 instructions.
 */
BEGIN_FUNC(arm_vector_table)
    ventry_invalid                         // Synchronous EL1t/EL2t
    ventry_invalid                         // IRQ EL1t/EL2t
    ventry_invalid                         // FIQ EL1t/EL2t
    ventry_invalid                         // SError EL1t/EL2t

    ventry  cur_el_sync                    // Current EL Synchronous (EL1/2)
    ventry  cur_el_irq                     // IRQ
    ventry_invalid                         // FIQ
    ventry_serror                          // SError

    ventry  lower_el_sync                  // Synchronous 64-bit EL0/EL1
    ventry  lower_el_irq                   // IRQ 64-bit EL0/EL1
    ventry_invalid                         // FIQ 64-bit EL0/EL1
    ventry_serror                          // SError 64-bit EL0/EL1

    ventry_invalid                         // Synchronous 32-bit EL0/EL1
    ventry_invalid                         // IRQ 32-bit EL0/EL1
    ventry_invalid                         // FIQ 32-bit EL0/EL1
    ventry_invalid                         // SError 32-bit EL0/EL1
END_FUNC(arm_vector_table)

.section .vectors.text, "ax"

.macro kernel_enter
    /* Storing thread's stack frame */
    stp     REG(0),  REG(1),  [sp, #(REGSIZE * 2) * 0]
    stp     REG(2),  REG(3),  [sp, #(REGSIZE * 2) * 1]
    stp     REG(4),  REG(5),  [sp, #(REGSIZE * 2) * 2]
    stp     REG(6),  REG(7),  [sp, #(REGSIZE * 2) * 3]
    stp     REG(8),  REG(9),  [sp, #(REGSIZE * 2) * 4]
    stp     REG(10), REG(11), [sp, #(REGSIZE * 2) * 5]
    stp     REG(12), REG(13), [sp, #(REGSIZE * 2) * 6]
    stp     REG(14), REG(15), [sp, #(REGSIZE * 2) * 7]
    stp     REG(16), REG(17), [sp, #(REGSIZE * 2) * 8]
    stp     REG(18), REG(19), [sp, #(REGSIZE * 2) * 9]
    stp     REG(20), REG(21), [sp, #(REGSIZE * 2) * 10]
    stp     REG(22), REG(23), [sp, #(REGSIZE * 2) * 11]
    stp     REG(24), REG(25), [sp, #(REGSIZE * 2) * 12]
    stp     REG(26), REG(27), [sp, #(REGSIZE * 2) * 13]
    stp     REG(28), REG(29), [sp, #(REGSIZE * 2) * 14]

    /* Store thread's SPSR, LR, and SP */
    mrs     REG(21), REGN(sp_el0)
    mrs     REG(22), ELR
    mrs     x23, SPSR
    stp     REG(30), REG(21), [sp, #PT_LR]
    stp     REG(22), REG(23), [sp, #PT_ELR_EL1]
#ifdef CONFIG_HAVE_CHERI
    mrs     c21, ddc_el0
    str     REG(21), [sp, #PT_DDC_EL0]
#endif
.endm

/* Takes argument x0: vect_offset (in debug builds) */
BEGIN_FUNC(invalid_vector_entry)
    lsp_i   x19
#ifdef CONFIG_DEBUG_BUILD
    mrs     REG(1), ELR
    bl      c_handle_invalid_vector_entry
#endif
    b       halt
END_FUNC(invalid_vector_entry)

BEGIN_FUNC(cur_el_sync)
    lsp_i   x19
    /* Read esr and branch to respective labels */
    mrs     x25, ESR
    lsr     x24, x25, #ESR_EC_SHIFT
    cmp     x24, #ESR_EC_CEL_DABT
    b.eq    cur_el_da
    cmp     x24, #ESR_EC_CEL_IABT
    b.eq    cur_el_ia
    b       cur_el_inv

cur_el_da:
#ifdef CONFIG_DEBUG_BUILD
    mrs     REG(0), ELR
    bl      kernelDataAbort
#endif /* CONFIG_DEBUG_BUILD */
    b       halt

cur_el_ia:
#ifdef CONFIG_DEBUG_BUILD
    mrs     REG(0), ELR
    bl      kernelPrefetchAbort
#endif /* CONFIG_DEBUG_BUILD */
    b       halt

cur_el_inv:
    /* 0x200 corresponding to the offset in the vector table */
    mov     x0, #0x200
    b       invalid_vector_entry
END_FUNC(cur_el_sync)

/*
 * This is only called if ksCurThread is idle thread.
 *
 * No need to store the state of idle thread and simply call c_handle_interrupt to
 * activate ksCurThread when returning from interrupt as long as idle thread is stateless.
 */
BEGIN_FUNC(cur_el_irq)
    lsp_i   x19
    b       c_handle_interrupt
END_FUNC(cur_el_irq)

BEGIN_FUNC(lower_el_sync)
    kernel_enter

    /* Read esr and branch to respective labels */
    mrs     x25, ESR
    lsr     x24, x25, #ESR_EC_SHIFT
    cmp     x24, #ESR_EC_LEL_DABT
    b.eq    lel_da
    cmp     x24, #ESR_EC_LEL_IABT
    b.eq    lel_ia
    cmp     x24, #ESR_EC_LEL_SVC64
    b.eq    lel_syscall
#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
    cmp     x24, #ESR_EC_LEL_HVC64
    b.eq    lel_syscall
    mrs     REG(20), ELR
    str     REG(20), [sp, #PT_FaultIP]

    lsp_i   x19
    /* move the ESR as the input */
    mov     x0, x25
    b       c_handle_vcpu_fault
#else
    b       el0_user
#endif

lel_da:
    mrs     REG(20), ELR
    str     REG(20), [sp, #PT_FaultIP]

    lsp_i   x19
    b       c_handle_data_fault

lel_ia:
    mrs     REG(20), ELR
    str     REG(20), [sp, #PT_FaultIP]

    lsp_i   x19
    b       c_handle_instruction_fault

lel_syscall:
    mrs     REG(20), ELR
    sub     REG(20), REG(20), #4
    str     REG(20), [sp, #PT_FaultIP]

    lsp_i   x19

#ifdef CONFIG_FASTPATH
    cmp     x7, #SYSCALL_CALL
    b.eq    c_handle_fastpath_call
#ifdef CONFIG_SIGNAL_FASTPATH
    cmp     x7, #SYSCALL_SEND
    b.eq    c_handle_fastpath_signal
#endif /* CONFIG_SIGNAL_FASTPATH */
    cmp     x7, #SYSCALL_REPLY_RECV
#ifdef CONFIG_KERNEL_MCS
    mov     x2, x6
#endif
    b.eq    c_handle_fastpath_reply_recv
#endif

    mov     x2, x7
    b       c_handle_syscall

el0_user:
    mrs     REG(20), ELR
    str     REG(20), [sp, #PT_FaultIP]

    lsp_i   x19
    b       c_handle_undefined_instruction
END_FUNC(lower_el_sync)

BEGIN_FUNC(lower_el_irq)
    kernel_enter
    mrs     REG(20), ELR
    str     REG(20), [sp, #PT_FaultIP]

    lsp_i   x19
    b       c_handle_interrupt
END_FUNC(lower_el_irq)
