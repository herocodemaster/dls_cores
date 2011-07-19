
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += mt9v032

V_DUT           += mt9v032_top.v

V_TESTBENCH     += mt9v032_top_tb.v

V_PARAMS_DEF    += \
    WIDTH=1

sims3:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)


