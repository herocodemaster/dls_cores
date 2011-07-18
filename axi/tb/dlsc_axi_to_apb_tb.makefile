
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_axi_to_apb.v

SP_TESTBENCH    += dlsc_axi_to_apb_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_apb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    DATA=32 \
    ADDR=32 \
    LEN=4

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

