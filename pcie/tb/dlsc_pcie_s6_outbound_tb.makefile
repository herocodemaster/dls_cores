
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm axi_tlm

V_DUT           += dlsc_pcie_s6_outbound.v

SP_TESTBENCH    += dlsc_pcie_s6_outbound_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp
SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    LEN=4 \
    TAG=5 \
    WRITE_SIZE=128 \
    READ_MOT=16 \
    READ_SIZE=2048 \
    READ_CPLH=8 \
    READ_CPLD=64 \
    READ_TIMEOUT=6250 \
    FCHB=8 \
    FCDB=12

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

