
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm wishbone_tlm

V_DUT           += dlsc_apb_to_wb.v

SP_TESTBENCH    += dlsc_apb_to_wb_tb.sp

SP_FILES        += dlsc_apb_tlm_master_32b.sp
SP_FILES        += dlsc_wishbone_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    REGISTER=1

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="REGISTER=0"

include $(DLSC_MAKEFILE_BOT)

