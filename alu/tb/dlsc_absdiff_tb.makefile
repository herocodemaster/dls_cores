
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_absdiff.v

SP_TESTBENCH    += dlsc_absdiff_tb.sp

V_PARAMS_DEF    += \
    WIDTH=16 \
    META=4

sims:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="WIDTH=9 META=15"

include $(DLSC_MAKEFILE_BOT)

