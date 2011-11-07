
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sp605 xilinx_sp605_pcie xilinx_sp605_mig

V_DIRS          += $(HOME)/projects/work/xilinx/dlsc_sp605/sim

V_DUT           += dlsc_sp605_top.v

V_TESTBENCH     += board.v
V_FILES         += tests.v

V_PARAMS_DEF    += 


sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

