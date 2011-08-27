
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_axi_rstcross.v

SP_TESTBENCH    += dlsc_axi_rstcross_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    MASTER_RESET=1 \
    SLAVE_RESET=1 \
    REGISTER=0 \
    DATA=32 \
    ADDR=32 \
    LEN=4 \
    MOT=16

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

