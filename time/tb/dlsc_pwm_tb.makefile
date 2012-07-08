
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += time csr_tlm

V_DUT           += dlsc_pwm.v

SP_TESTBENCH    += dlsc_pwm_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    BITS=16 \
    SBITS=8 \
    CHANNELS=8 \
    TIMEBASES=4 \
    TRIGGERS=4 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

