
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += window

V_DUT           += dlsc_window_front.v

SP_TESTBENCH    += dlsc_window_front_tb.sp

V_PARAMS_DEF    += \
    CYCLES=2 \
    WINX=7 \
    WINY=7 \
    MAXX=1024 \
    XB=10 \
    YB=10 \
    BITS=32 \
    EDGE_MODE=2

$(call dlsc-sim,"")
$(call dlsc-sim,"CYCLES=1")
$(call dlsc-sim,"CYCLES=6")
$(call dlsc-sim,"WINX=1 WINY=3")
$(call dlsc-sim,"WINX=3 WINY=3")
$(call dlsc-sim,"WINX=5 WINY=9")
$(call dlsc-sim,"WINY=9 WINX=5")
$(call dlsc-sim,"BITS=8")

include $(DLSC_MAKEFILE_BOT)

