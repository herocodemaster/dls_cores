
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_min_tree.v

SP_TESTBENCH    += dlsc_min_tree_tb.sp

V_PARAMS_DEF    += \
    DATA=24 \
    ID=8 \
    META=4 \
    INPUTS=9 \
    PIPELINE=0

sims:
	$(MAKE) -f $(THIS) V_PARAMS="PIPELINE=0"
	$(MAKE) -f $(THIS) V_PARAMS="PIPELINE=1"
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=1"

include $(DLSC_MAKEFILE_BOT)

