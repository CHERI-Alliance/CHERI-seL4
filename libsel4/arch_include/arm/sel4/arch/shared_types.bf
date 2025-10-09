--
-- Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
--
-- SPDX-License-Identifier: BSD-2-Clause
--

-- this file contains types shared between libsel4 and the kernel

tagged_union seL4_Fault seL4_FaultType {
    -- generic faults
    tag NullFault 0
    tag CapFault 1
    tag UnknownSyscall 2
    tag UserException 3
#ifdef CONFIG_HARDWARE_DEBUG_API
    tag DebugException 4
#endif
#ifdef CONFIG_KERNEL_MCS
    tag Timeout 5

    -- arch specific faults
    tag VMFault 6

#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
    tag VGICMaintenance 7
    tag VCPUFault 8
    tag VPPIEvent 9
#endif
#else
    -- arch specific faults
    tag VMFault 5

#ifdef CONFIG_ARM_HYPERVISOR_SUPPORT
    tag VGICMaintenance 6
    tag VCPUFault 7
    tag VPPIEvent 8
#endif
#endif

}

#ifdef CONFIG_HAVE_CHERI
-- Unpacked CHERI cap metadata passed to the kernel as an argument, from which the
-- kernel could construct an actual (compressed) CHERI capability, besides other
-- fields such as base, length, and address. The following format is just a
-- software definition and does not correspond to an architectural CHERI capability.
block CheriCapMeta {
    padding         22
    field AP        18
    field T         15
    field flags     8
    field V         1
}
#endif
