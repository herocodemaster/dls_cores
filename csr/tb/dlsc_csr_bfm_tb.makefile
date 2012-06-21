
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += csr

V_DUT           += dlsc_csr_bfm.v

V_TESTBENCH     += dlsc_csr_bfm_tb.v

V_PARAMS_DEF    += \
    ADDR=32 \
    DATA=32

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)


