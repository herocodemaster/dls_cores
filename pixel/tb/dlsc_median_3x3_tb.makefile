
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel

V_DUT           += dlsc_median_3x3.v

SP_TESTBENCH    += dlsc_median_3x3_tb.sp

V_PARAMS_DEF    += \
    BITS=8

$(call dlsc-sim,"")
$(call dlsc-sim,"12")
$(call dlsc-sim,"32")

include $(DLSC_MAKEFILE_BOT)

