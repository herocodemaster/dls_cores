
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += time csr_tlm

V_DUT           += dlsc_timebase.v

SP_TESTBENCH    += dlsc_timebase_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    DIV0=1 \
    DIV1=10 \
    DIV2=100 \
    DIV3=1000 \
    DIV4=10000 \
    DIV5=100000 \
    DIV6=1000000 \
    DIV7=10000000

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

