
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_adder_tree.v

SP_TESTBENCH    += dlsc_adder_tree_tb.sp

V_PARAMS_DEF    += \
    IN_BITS=16 \
    OUT_BITS=32 \
    INPUTS=9 \
    META=4

sims:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=1 META=9"
	$(MAKE) -f $(THIS) V_PARAMS="IN_BITS=9 OUT_BITS=10 INPUTS=2"

include $(DLSC_MAKEFILE_BOT)

