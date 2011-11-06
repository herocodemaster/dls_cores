
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sp605 axi_tlm pcie_tlm

V_DUT           += dlsc_sp605_core.v

SP_TESTBENCH    += dlsc_sp605_core_tb.sp

SP_FILES        += dlsc_pcie_s6_model.sp
SP_FILES        += dlsc_sp605_mig_model.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    LOCAL_DMA_DESC=1 \
    SRAM_SIZE=65536

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="LOCAL_DMA_DESC=0"

include $(DLSC_MAKEFILE_BOT)

