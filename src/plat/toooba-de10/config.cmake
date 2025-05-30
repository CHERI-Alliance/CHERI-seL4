#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
# Copyright (c) 2025, Capabilities Ltd <heshamalmatary@capabilitieslimited.co.uk>

# SPDX-License-Identifier: GPL-2.0-only
#

cmake_minimum_required(VERSION 3.7.2)

declare_platform(toooba-de10 KernelPlatformTooobaDE10 PLAT_TOOOBA_DE10 KernelSel4ArchRiscV64)

if(KernelPlatformTooobaDE10)
    declare_seL4_arch(riscv64)
    config_set(KernelRiscVPlatform RISCV_PLAT "toooba-de10")
    config_set(KernelOpenSBIPlatform OPENSBI_PLATFORM "generic")
    config_set(KernelPlatformFirstHartID FIRST_HART_ID 0)

    list(APPEND KernelDTSList "tools/dts/toooba-de10.dts")
    list(APPEND KernelDTSList "src/plat/toooba-de10/overlay-toooba-de10.dts")
    declare_default_headers(
        TIMER_FREQUENCY 0x5f5e100
        MAX_IRQ 16
        INTERRUPT_CONTROLLER drivers/irq/riscv_plic0.h
    )
else()
    unset(KernelPlatformFirstHartID CACHE)
endif()
