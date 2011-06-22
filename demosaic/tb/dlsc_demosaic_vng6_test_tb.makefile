
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += demosaic

V_DUT           += dlsc_demosaic_vng6_test.v

SP_TESTBENCH    += dlsc_demosaic_vng6_test_tb.sp

V_PARAMS_DEF    += \
    DATA=8

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

