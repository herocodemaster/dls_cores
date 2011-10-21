
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sp605 axi_tlm pcie_tlm

V_DUT           += dlsc_sp605_core.v

SP_TESTBENCH    += dlsc_sp605_core_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp
SP_FILES        += dlsc_sp605_mig_model.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += 

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

