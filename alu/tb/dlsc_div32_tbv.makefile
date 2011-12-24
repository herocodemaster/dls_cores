
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_div32.v

V_TESTBENCH     += dlsc_div32_tbv.v

V_PARAMS_DEF    +=

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

