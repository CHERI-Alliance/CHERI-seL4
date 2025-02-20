#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
# Copyright (c) 2025, Capabilities Ltd <heshamalmatary@capabilitieslimited.co.uk>

# SPDX-License-Identifier: GPL-2.0-only
#

cmake_minimum_required(VERSION 3.7.2)

declare_platform(toooba-besspin KernelPlatformTooobaBesspin PLAT_TOOOBA_BESSPIN KernelSel4ArchRiscV64)

if(KernelPlatformTooobaBesspin)
    declare_seL4_arch(riscv64)
    config_set(KernelRiscVPlatform RISCV_PLAT "toooba-besspin")
    config_set(KernelOpenSBIPlatform OPENSBI_PLATFORM "generic")
    config_set(KernelPlatformFirstHartID FIRST_HART_ID 0)

    list(APPEND KernelDTSList "tools/dts/toooba-besspin.dts")
    list(APPEND KernelDTSList "src/plat/toooba-besspin/overlay-toooba-besspin.dts")
    declare_default_headers(
        TIMER_FREQUENCY 25000000
        MAX_IRQ 15
        INTERRUPT_CONTROLLER drivers/irq/riscv_plic0.h
    )
else()
    unset(KernelPlatformFirstHartID CACHE)
endif()
