
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_axi_router_tb.v

SP_TESTBENCH    += dlsc_axi_router_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    DATA=32 \
    LEN=4 \
    BUFFER=1 \
    MOT=16 \
    LANES=1 \
    INPUTS=1 \
    OUTPUTS=1

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

