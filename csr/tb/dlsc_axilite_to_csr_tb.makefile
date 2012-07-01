
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += csr_tlm axi_tlm

V_DUT           += dlsc_axilite_to_csr.v

SP_TESTBENCH    += dlsc_axilite_to_csr_tb.sp

SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_csr_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    DATA=32 \
    ADDR=32

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

