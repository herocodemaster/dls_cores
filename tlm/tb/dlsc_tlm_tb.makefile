
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += tlm

SP_TESTBENCH    += dlsc_tlm_tb.sp

V_PARAMS_DEF    += \
    REMOVE_ANNOTATION=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="REMOVE_ANNOTATION=1"

include $(DLSC_MAKEFILE_BOT)

