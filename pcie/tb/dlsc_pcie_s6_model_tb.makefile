
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm

SP_TESTBENCH    += dlsc_pcie_s6_model_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp

V_PARAMS_DEF    +=

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

