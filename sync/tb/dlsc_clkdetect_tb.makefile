
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sync

V_DUT           += dlsc_clkdetect.v

SP_TESTBENCH    += dlsc_clkdetect_tb.sp

V_PARAMS_DEF    += \
    PROP=15\
    FILTER=15

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="PROP=63"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="FILTER=3"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="PROP=31 FILTER=7"

include $(DLSC_MAKEFILE_BOT)

