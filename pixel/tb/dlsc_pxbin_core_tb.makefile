
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel csr_tlm

V_DUT           += dlsc_pxbin_core.v

SP_TESTBENCH    += dlsc_pxbin_common_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    CORE_TEST=1 \
    BITS=8 \
    WIDTH=1024 \
    XB=12 \
    YB=12 \
    BINB=3

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

