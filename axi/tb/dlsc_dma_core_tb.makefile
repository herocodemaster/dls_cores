
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_dma_core.v

SP_TESTBENCH    += dlsc_dma_core_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    APB_ADDR=32 \
    CMD_ADDR=32 \
    CMD_LEN=4 \
    READ_ADDR=32 \
    READ_LEN=4 \
    READ_MOT=16 \
    WRITE_ADDR=32 \
    WRITE_LEN=4 \
    WRITE_MOT=16 \
    DATA=32 \
    TRIGGERS=8

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

