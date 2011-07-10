
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm

V_DUT           += dlsc_pcie_s6_inbound_read.v

SP_TESTBENCH    += dlsc_pcie_s6_inbound_read_tb.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    LEN=4 \
    BUFA=8 \
    TOKN=4

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="TOKN=2 ADDR=16"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="TOKN=6"
	$(MAKE) -f $(THIS) V_PARAMS="BUFA=6"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="LEN=2 BUFA=4"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="LEN=6"
	$(MAKE) -f $(THIS) V_PARAMS="BUFA=12"

include $(DLSC_MAKEFILE_BOT)

