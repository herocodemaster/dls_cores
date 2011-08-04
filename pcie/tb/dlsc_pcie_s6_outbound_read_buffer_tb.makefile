
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie

V_DUT           += dlsc_pcie_s6_outbound_read_buffer.v

SP_TESTBENCH    += dlsc_pcie_s6_outbound_read_buffer_tb.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    LEN=4 \
    TAG=5 \
    BUFA=9 \
    MOT=16

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

