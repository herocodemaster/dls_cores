
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_mult32.v

SP_TESTBENCH    += dlsc_mult32_tb.sp

V_PARAMS_DEF    += \
    REGISTER=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER=1"

include $(DLSC_MAKEFILE_BOT)

