
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel csr_tlm

V_DUT           += dlsc_grayscale.v

SP_TESTBENCH    += dlsc_grayscale_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    BITS=8 \
    CBITS=4 \
    CHANNELS=1 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="CHANNELS=3 BITS=12 CORE_INSTANCE=837492"

include $(DLSC_MAKEFILE_BOT)

