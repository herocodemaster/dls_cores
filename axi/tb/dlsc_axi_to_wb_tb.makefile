
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm wishbone_tlm

V_DUT           += dlsc_axi_to_wb.v

SP_TESTBENCH    += dlsc_axi_to_wb_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_wishbone_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    WB_PIPELINE=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="WB_PIPELINE=1"

include $(DLSC_MAKEFILE_BOT)

