
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_axi_ram.v

SP_TESTBENCH    += dlsc_axi_ram_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp

V_PARAMS_DEF    += \
    SIZE=8192 \
    DATA=32 \
    ADDR=32 \
    LEN=4

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="SIZE=65536 LEN=8"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="SIZE=1024 LEN=2"

include $(DLSC_MAKEFILE_BOT)

