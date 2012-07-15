
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel csr_tlm

V_DUT           += dlsc_pxbin.v

SP_TESTBENCH    += dlsc_pxbin_common_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp

# CSR_DOMAIN defaults to 0
# PX_DOMAIN defaults to 1
# ..will force PX_DOMAIN to 0 when testing sync operation

V_PARAMS_DEF    += \
    BITS=8 \
    MAX_WIDTH=1024 \
    MAX_HEIGHT=1024 \
    MAX_BIN=8 \
    CORE_INSTANCE=42

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="PX_DOMAIN=0"

include $(DLSC_MAKEFILE_BOT)

