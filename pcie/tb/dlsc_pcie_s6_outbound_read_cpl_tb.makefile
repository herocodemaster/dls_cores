
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm

V_DUT           += dlsc_pcie_s6_outbound_read_cpl.v

SP_TESTBENCH    += dlsc_pcie_s6_outbound_read_cpl_tb.sp

V_PARAMS_DEF    += \
    TAG=5 \
    TIMEOUT=6250

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

