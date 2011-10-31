
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += opencores axi_tlm

V_DUT           += i2c_master_top_apb.v

SP_TESTBENCH    += i2c_master_top_apb_tb.sp

SP_FILES        += dlsc_apb_tlm_master_32b.sp

V_PARAMS_DEF    +=

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

