/*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 * Copyright 2024-2025, Capabilities Limited
 * CHERI support contributed by Capabilities Limited was developed by Hesham Almatary
 *
 * SPDX-License-Identifier: GPL-2.0-only
 */

#include <config.h>
#include <model/statedata.h>
#include <arch/fastpath/fastpath.h>
#include <arch/kernel/traps.h>
#include <api/syscall.h>
#include <linker.h>
#include <machine/fpu.h>

#include <benchmark/benchmark_track.h>
#include <benchmark/benchmark_utilisation.h>

/** DONT_TRANSLATE */
void VISIBLE NORETURN restore_user_context(void)
{
    c_exit_hook();

#ifdef ARM_CP14_SAVE_AND_RESTORE_NATIVE_THREADS
    restore_user_debug_context(NODE_STATE(ksCurThread));
#endif

#ifdef CONFIG_HAVE_FPU
    lazyFPURestore(NODE_STATE(ksCurThread));
#endif /* CONFIG_HAVE_FPU */

    NODE_UNLOCK_IF_HELD;

    asm volatile(
        "mov     sp, %0                                             \n"

        /* Restore thread's SPSR, LR, and SP */
        "ldp     "REG(21)", "REG(22)", [sp, %[SP_EL0]]              \n"
        "ldr     "REG(23)", [sp, %[SPSR_EL1]]                       \n"

#if defined(CONFIG_HAVE_CHERI)
        /* Restore thread's DDC */
        "ldr     "REG(24)", [sp, %[DDC_EL0]]                        \n"
#endif

        "msr     "REGN(sp_el0)", " REG(21)"                         \n"
#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
        "msr     "REGN(elr_el2)", "REG(22)"                         \n"
        "msr     spsr_el2, x23                                      \n"
#else
        "msr     "REGN(elr_el1)", "REG(22)"                         \n"
        "msr     spsr_el1, x23                                      \n"
#endif

#if defined(CONFIG_HAVE_CHERI)
        "msr     ddc_el0, c24                                       \n"
#endif

        /* Restore remaining registers */
        "ldp     "REG(0)",  "REG(1)",  [sp, #(%[REGSZ] * 2) * 0]    \n"
        "ldp     "REG(2)",  "REG(3)",  [sp, #(%[REGSZ] * 2) * 1]    \n"
        "ldp     "REG(4)",  "REG(5)",  [sp, #(%[REGSZ] * 2) * 2]    \n"
        "ldp     "REG(6)",  "REG(7)",  [sp, #(%[REGSZ] * 2) * 3]    \n"
        "ldp     "REG(8)",  "REG(9)",  [sp, #(%[REGSZ] * 2) * 4]    \n"
        "ldp     "REG(10)", "REG(11)", [sp, #(%[REGSZ] * 2) * 5]    \n"
        "ldp     "REG(12)", "REG(13)", [sp, #(%[REGSZ] * 2) * 6]    \n"
        "ldp     "REG(14)", "REG(15)", [sp, #(%[REGSZ] * 2) * 7]    \n"
        "ldp     "REG(16)", "REG(17)", [sp, #(%[REGSZ] * 2) * 8]    \n"
        "ldp     "REG(18)", "REG(19)", [sp, #(%[REGSZ] * 2) * 9]    \n"
        "ldp     "REG(20)", "REG(21)", [sp, #(%[REGSZ] * 2) * 10]   \n"
        "ldp     "REG(22)", "REG(23)", [sp, #(%[REGSZ] * 2) * 11]   \n"
        "ldp     "REG(24)", "REG(25)", [sp, #(%[REGSZ] * 2) * 12]   \n"
        "ldp     "REG(26)", "REG(27)", [sp, #(%[REGSZ] * 2) * 13]   \n"
        "ldp     "REG(28)", "REG(29)", [sp, #(%[REGSZ] * 2) * 14]   \n"
        "ldr     "REG(30)", [sp, %[LR]]                             \n"
        "eret"
        :
        : "r"(NODE_STATE(ksCurThread)->tcbArch.tcbContext.registers),
        [SP_EL0] "i"(PT_SP_EL0), [SPSR_EL1] "i"(PT_SPSR_EL1), [LR] "i"(PT_LR),
#if defined(CONFIG_HAVE_CHERI)
        [DDC_EL0] "i"(PT_DDC_EL0),
#endif
        [REGSZ] "i"(REGSIZE)
        : "memory"
    );
    UNREACHABLE();
}
