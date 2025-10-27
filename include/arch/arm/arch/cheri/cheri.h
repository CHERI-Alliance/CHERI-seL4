/*
 * Copyright 2025, Capabilities Limited
 * CHERI support contributed by Capabilities Limited was developed by Hesham Almatary
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
#pragma once

#include <mode/machine/registerset.h>

#define CHERI_INT_MODE 0
#define CHERI_CAP_MODE 1

#define CPACR_CEN_MASK    (0x3 << 18)
#define CPACR_CEN_TRAP_NONE  (0x3 << 18) /* No traps */

/* CCTLR_EL0 - Capability Control Register */
#define CCTLR_SBL_MASK    (0x1 << 7) /* Capability sealing by branch and link */
#define CCTLR_PERMVCT_MASK  (0x1 << 6) /* Permit access to CNTVCT w/o System */

void *__capability CheriArch_BuildCap(void *__capability src, word_t base, word_t addr, word_t size,
                                      CheriCapMeta_t meta, int user);
CheriCapMeta_t CheriArch_GetCapMeta(void *__capability src);

static inline int CheriArch_isIntegerMode(void *__capability cap)
{
    return ((__builtin_cheri_address_get(cap) & 0x1) == CHERI_INT_MODE);
}

static inline void CheriArch_init_user(void)
{
    word_t tmp;
    /* Enable Morello instructions at EL0 and EL1 */
    asm volatile("mrs %0, cpacr_el1  \n"
                 "bic %0, %0, %1     \n"
                 "orr %0, %0, %2     \n"
                 "msr cpacr_el1, %0  \n"
                 : "+r"(tmp)
                 :"i"(CPACR_CEN_MASK), "i"(CPACR_CEN_TRAP_NONE):);

    /*
     * Allow access to CNTVCT_EL0 without PCC System permission and enable
     * capability sealing for branch and link at EL0.
     */
    asm volatile("mrs %0, cctlr_el0  \n"
                 "orr %0, %0, %1     \n"
                 "msr cctlr_el0, %0  \n"
                 : "+r"(tmp)
                 :"i"(CCTLR_PERMVCT_MASK | CCTLR_SBL_MASK):);
}

static inline void *__capability CheriArch_get_pcc(void)
{
    return __builtin_cheri_program_counter_get();
}

static inline void CheriArch_initContext(user_context_t *context, void *__user pcc)
{
    context->registers[FaultIP] = (rword_t)pcc;

    if (CheriArch_isIntegerMode(pcc)) {
        void *__user root_ddc = CheriArch_get_pcc();
        root_ddc = __builtin_cheri_perms_and(root_ddc, ~(__CHERI_CAP_PERMISSION_PERMIT_EXECUTE__));
        root_ddc = __builtin_cheri_address_set(root_ddc, 0);
        context->registers[DDC] = (rword_t)root_ddc;
    } else {
        context->registers[SPSR_EL1] |= PMODE_C64;
        /* Invalidate DDC; it shouldn't be used in capmode */
        context->registers[DDC] = 0;
    }
}
