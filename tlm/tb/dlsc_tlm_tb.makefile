
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += tlm

# TODO
V_DUT           += dlsc_empty.v

SP_TESTBENCH    += dlsc_tlm_tb.sp

V_PARAMS_DEF    +=

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

