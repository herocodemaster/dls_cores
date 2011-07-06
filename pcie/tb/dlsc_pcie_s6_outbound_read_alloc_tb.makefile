
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pcie_tlm

V_DUT           += dlsc_pcie_s6_outbound_read_alloc.v

SP_TESTBENCH    += dlsc_pcie_s6_outbound_read_alloc_tb.sp

V_PARAMS_DEF    += \
    ADDR=32 \
    TAG=5 \
    BUFA=9 \
    CPLH=8 \
    CPLD=64

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="BUFA=8 CPLH=16 CPLD=64 TAG=6"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="BUFA=10 CPLH=64 CPLD=256"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="BUFA=12 CPLH=32 CPLD=128 TAG=4"

include $(DLSC_MAKEFILE_BOT)

