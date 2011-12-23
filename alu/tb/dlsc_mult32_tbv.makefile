
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu xilinx

V_DUT           += dlsc_mult32.v

V_TESTBENCH     += dlsc_mult32_tbv.v

V_PARAMS_DEF    += \
    DEVICE=GENERIC \
    REGISTER=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER=1"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=SPARTAN6"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=VIRTEX6"

include $(DLSC_MAKEFILE_BOT)

