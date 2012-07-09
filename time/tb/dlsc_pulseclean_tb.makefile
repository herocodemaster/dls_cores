
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += time csr_tlm

V_DUT           += dlsc_pulseclean.v

SP_TESTBENCH    += dlsc_pulseclean_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    SYNC=1 \
    FILTER=16 \
    CHANNELS=4 \
    TIMEBASES=4 \
    BITS=16 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

