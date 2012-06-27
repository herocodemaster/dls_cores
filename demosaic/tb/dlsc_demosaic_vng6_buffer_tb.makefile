
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += demosaic

V_DUT           += dlsc_demosaic_vng6_buffer.v

SP_TESTBENCH    += dlsc_demosaic_vng6_buffer_tb.sp

V_PARAMS_DEF    += \
    BITS=8 \
    XB=12 \
    YB=12

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

