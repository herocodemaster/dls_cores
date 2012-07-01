
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += time csr_tlm

V_DUT           += dlsc_timer_capture.v

SP_TESTBENCH    += dlsc_timer_capture_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    INPUTS=1 \
    META=8 \
    CHANNELS=1 \
    NOMUX=0 \
    DEPTH=16 \
    PBITS=4 \
    EBITS=8 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=16"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=16 CHANNELS=16 NOMUX=1"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=30 CHANNELS=10"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="INPUTS=64 META=32 CHANNELS=16 DEPTH=32 CORE_INSTANCE=29387"

include $(DLSC_MAKEFILE_BOT)

