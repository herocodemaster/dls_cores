
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += window

V_DUT           += dlsc_window_pipedelay.v

V_TESTBENCH     += dlsc_window_pipedelay_tb.v

V_PARAMS_DEF    += \
    WIN_DELAY=2 \
    PIPE_DELAY=6 \
    META=16

$(call dlsc-sim,"")
$(call dlsc-sim,"META=0")
$(call dlsc-sim,"WIN_DELAY=0")
$(call dlsc-sim,"PIPE_DELAY=0")
$(call dlsc-sim,"WIN_DELAY=0 PIPE_DELAY=0")

include $(DLSC_MAKEFILE_BOT)

