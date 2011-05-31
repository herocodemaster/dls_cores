
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_mult32.v

SP_TESTBENCH    += dlsc_mult32_tb.sp

V_PARAMS_DEF    +=

sims:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

