
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += quad csr_tlm

V_DUT           += dlsc_quad_decoder.v

SP_TESTBENCH    += dlsc_quad_decoder_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

V_PARAMS_DEF    += \
    FILTER=16 \
    BITS=16

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

