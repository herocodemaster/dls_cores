
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm axi_tlm

V_DUT           += dlsc_pcie_s6_outbound.v

SP_TESTBENCH    += dlsc_pcie_s6_outbound_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp
SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    ASYNC=0 \
    ADDR=32 \
    LEN=4 \
    WRITE_EN=1 \
    WRITE_SIZE=128 \
    READ_EN=1 \
    READ_MOT=16 \
    READ_CPLH=8 \
    READ_CPLD=64 \
    READ_TIMEOUT=6250 \
    TAG=5 \
    FCHB=8 \
    FCDB=12

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="READ_EN=0"
	$(MAKE) -f $(THIS) V_PARAMS="WRITE_EN=0"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="ASYNC=1"
	$(MAKE) -f $(THIS) V_PARAMS="ASYNC=1 READ_EN=0"
	$(MAKE) -f $(THIS) V_PARAMS="ASYNC=1 WRITE_EN=0"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="LEN=8 WRITE_SIZE=512 READ_CPLH=32 READ_CPLD=256"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="LEN=8 WRITE_SIZE=512 READ_CPLH=32 READ_CPLD=256 ASYNC=1"

include $(DLSC_MAKEFILE_BOT)

