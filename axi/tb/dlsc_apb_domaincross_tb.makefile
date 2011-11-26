
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += axi_tlm

V_DUT           += dlsc_apb_domaincross.v

SP_TESTBENCH    += dlsc_apb_domaincross_tb.sp

SP_FILES        += dlsc_apb_tlm_master_32b.sp
SP_FILES        += dlsc_apb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    DATA=32 \
    ADDR=32 \
    RESET_SLVERR=1 \
    M_CLK=10.0 \
    S_CLK=11.3

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="M_CLK=10.0 S_CLK=10.0"
	$(MAKE) -f $(THIS) V_PARAMS="M_CLK=10.0 S_CLK=99.3"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="M_CLK=101.1 S_CLK=10.0"
	$(MAKE) -f $(THIS) V_PARAMS="M_CLK=100.0 S_CLK=1.0"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="M_CLK=1.0 S_CLK=100.0"

include $(DLSC_MAKEFILE_BOT)

