
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += time csr_tlm

V_DUT           += dlsc_timer_capture.v

SP_TESTBENCH    += dlsc_timer_capture_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    INPUTS=1 \
    CHANNELS=1 \
    DEPTH=16 \
    PBITS=4 \
    EBITS=8 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

