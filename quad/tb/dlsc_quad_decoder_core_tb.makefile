
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += quad

V_DUT           += dlsc_quad_decoder_core.v

SP_TESTBENCH    += dlsc_quad_decoder_core_tb.sp

V_PARAMS_DEF    += \
    FILTER=4 \
    BITS=16

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

