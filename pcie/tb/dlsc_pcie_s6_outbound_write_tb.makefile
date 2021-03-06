
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie

V_DUT           += dlsc_pcie_s6_outbound_write.v

SP_TESTBENCH    += dlsc_pcie_s6_outbound_write_tb.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    LEN=4 \
    MAX_SIZE=128 \
    FCHB=8 \
    FCDB=12

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="MAX_SIZE=256"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="LEN=1"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="LEN=8"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=13"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=13 LEN=2 MAX_SIZE=256"

include $(DLSC_MAKEFILE_BOT)

