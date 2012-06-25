
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += demosaic

V_DUT           += dlsc_demosaic_vng6_core.v

SP_TESTBENCH    += dlsc_demosaic_vng6_core_tb.sp

V_PARAMS_DEF    += \
    BITS=8 \
    WIDTH=1024 \
    XB=12 \
    YB=12

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

