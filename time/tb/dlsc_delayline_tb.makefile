
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += time csr_tlm

V_DUT           += dlsc_delayline.v

SP_TESTBENCH    += dlsc_delayline_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    DATA=8 \
    CHANNELS=1 \
    TIMEBASES=4 \
    DELAY=32 \
    INERTIAL=0 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

