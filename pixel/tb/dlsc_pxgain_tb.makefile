
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel csr_tlm

V_DUT           += dlsc_pxgain.v

SP_TESTBENCH    += dlsc_pxgain_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    BITS=8 \
    CHANNELS=3 \
    MAX_H=4096 \
    MAX_V=4096 \
    GAINB=17 \
    DIVB=12 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

