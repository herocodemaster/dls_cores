
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_adder_tree.v

SP_TESTBENCH    += dlsc_adder_tree_tb.sp

V_PARAMS_DEF    += \
    SIGNED=0 \
    IN_BITS=16 \
    OUT_BITS=32 \
    INPUTS=9 \
    META=4

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="SIGNED=1"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=1 META=9"
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=1 META=9 SIGNED=1"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="IN_BITS=9 OUT_BITS=10 INPUTS=2"
	$(MAKE) -f $(THIS) V_PARAMS="IN_BITS=9 OUT_BITS=10 INPUTS=2 SIGNED=1"

include $(DLSC_MAKEFILE_BOT)

