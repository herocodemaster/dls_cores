
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_mult32.v

SP_TESTBENCH    += dlsc_mult32_tb.sp

V_PARAMS_DEF    += \
    REGISTER_IN=1 \
    REGISTER_OUT=1

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER_IN=0"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER_OUT=0"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER_OUT=0 REGISTER_IN=0"

include $(DLSC_MAKEFILE_BOT)

