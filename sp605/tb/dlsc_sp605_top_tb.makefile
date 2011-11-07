
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sp605 xilinx_sp605_pcie xilinx_sp605_mig

V_DUT           += dlsc_sp605_top.v

V_TESTBENCH     += dlsc_sp605_top_tb.v
V_FILES         += board.v

V_PARAMS_DEF    += 


sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

