#
# Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
# Copyright (c) 2025, Capabilities Ltd <heshamalmatary@capabilitieslimited.co.uk>

# SPDX-License-Identifier: GPL-2.0-only
#

cmake_minimum_required(VERSION 3.7.2)

declare_platform(hobgoblin-vcu118 KernelPlatformHobGoblinVcu118 PLAT_HOBGOBLIN_VCU118 KernelSel4ArchRiscV64)

if(KernelPlatformHobGoblinVcu118)
    declare_seL4_arch(riscv64)
    config_set(KernelRiscVPlatform RISCV_PLAT "hobgoblin-vcu118")
    config_set(KernelOpenSBIPlatform OPENSBI_PLATFORM "generic")
    config_set(KernelPlatformFirstHartID FIRST_HART_ID 0)

    list(APPEND KernelDTSList "tools/dts/hobgoblin-vcu118.dts")
    list(APPEND KernelDTSList "src/plat/hobgoblin-vcu118/overlay-hobgoblin-vcu118.dts")
    declare_default_headers(
        TIMER_FREQUENCY 0x5f5e100
        MAX_IRQ 30
        INTERRUPT_CONTROLLER drivers/irq/riscv_plic0.h
    )
else()
    unset(KernelPlatformFirstHartID CACHE)
endif()
