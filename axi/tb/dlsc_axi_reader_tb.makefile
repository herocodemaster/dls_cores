
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_axi_reader.v

SP_TESTBENCH    += dlsc_axi_reader_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    LEN=4 \
    BLEN=12 \
    MOT=16 \
    FIFO_ADDR=8 \
    STROBE_EN=1 \
    WARNINGS=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

