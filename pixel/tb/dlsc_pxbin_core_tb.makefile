
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel

V_DUT           += dlsc_pxbin_core.v

SP_TESTBENCH    += dlsc_pxbin_core_tb.sp

V_PARAMS_DEF    += \
    BITS=8 \
    WIDTH=1024 \
    XB=12 \
    YB=12 \
    BINB=3

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

