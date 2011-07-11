
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm axi_tlm

V_DUT           += dlsc_pcie_s6_inbound.v

SP_TESTBENCH    += dlsc_pcie_s6_inbound_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    LEN=4 \
    WRITE_BUFFER=32 \
    WRITE_MOT=16 \
    READ_BUFFER=256 \
    READ_MOT=16

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

