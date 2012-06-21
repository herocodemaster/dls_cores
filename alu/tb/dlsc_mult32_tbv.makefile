
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu xilinx

V_DUT           += dlsc_mult32.v

V_TESTBENCH     += dlsc_mult32_tbv.v

V_PARAMS_DEF    += \
    DEVICE=GENERIC \
    REGISTER_IN=1 \
    REGISTER_OUT=1

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER_IN=0"
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER_OUT=0"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER_OUT=0 REGISTER_IN=0"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=SPARTAN6"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=SPARTAN6 REGISTER_IN=0"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=SPARTAN6 REGISTER_OUT=0"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=SPARTAN6 REGISTER_OUT=0 REGISTER_IN=0"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=VIRTEX6"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=VIRTEX6 REGISTER_IN=0"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=VIRTEX6 REGISTER_OUT=0"
	$(MAKE) -f $(THIS) V_PARAMS="DEVICE=VIRTEX6 REGISTER_OUT=0 REGISTER_IN=0"

include $(DLSC_MAKEFILE_BOT)
