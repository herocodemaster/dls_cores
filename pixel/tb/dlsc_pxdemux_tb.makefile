
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel csr_tlm

V_DUT           += dlsc_pxdemux.v

SP_TESTBENCH    += dlsc_pxdemux_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    BITS=8 \
    STREAMS=4 \
    MAX_H=4096 \
    MAX_V=4096 \
    BUFFER=16 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

