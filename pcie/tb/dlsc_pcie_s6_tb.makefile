
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm axi_tlm

V_DUT           += dlsc_pcie_s6.v

SP_TESTBENCH    += dlsc_pcie_s6_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp
SP_FILES        += dlsc_apb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    APB_CLK_DOMAIN=0 \
    IB_CLK_DOMAIN=0 \
    OB_CLK_DOMAIN=0 \
    APB_EN=1 \
    APB_ADDR=32 \
    AUTO_POWEROFF=1 \
    INTERRUPTS=1 \
    INT_ASYNC=1 \
    IB_ADDR=32 \
    IB_LEN=4 \
    IB_WRITE_EN=1 \
    IB_WRITE_BUFFER=32 \
    IB_WRITE_MOT=16 \
    IB_READ_EN=1 \
    IB_READ_BUFFER=256 \
    IB_READ_MOT=16 \
    OB_ADDR=32 \
    OB_LEN=4 \
    OB_WRITE_EN=1 \
    OB_WRITE_SIZE=128 \
    OB_WRITE_MOT=16 \
    OB_READ_EN=1 \
    OB_READ_MOT=16 \
    OB_READ_CPLH=8 \
    OB_READ_CPLD=64 \
    OB_READ_TIMEOUT=62500 \
    OB_TAG=5 \
    OB_TRANS_REGIONS=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="APB_CLK_DOMAIN=1"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="IB_CLK_DOMAIN=3"
	$(MAKE) -f $(THIS) V_PARAMS="OB_CLK_DOMAIN=3"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="IB_CLK_DOMAIN=3 OB_CLK_DOMAIN=3"
	$(MAKE) -f $(THIS) V_PARAMS="IB_CLK_DOMAIN=3 OB_CLK_DOMAIN=2"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="IB_CLK_DOMAIN=3 OB_CLK_DOMAIN=3 APB_CLK_DOMAIN=3"
	$(MAKE) -f $(THIS) V_PARAMS="IB_CLK_DOMAIN=2 OB_CLK_DOMAIN=3 APB_CLK_DOMAIN=1"
	$(MAKE) -f $(THIS) V_PARAMS="OB_LEN=8 OB_WRITE_SIZE=512 OB_READ_CPLH=32 OB_READ_CPLD=256"

include $(DLSC_MAKEFILE_BOT)

