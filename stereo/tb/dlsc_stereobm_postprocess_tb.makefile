
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += stereo

V_DUT           += dlsc_stereobm_postprocess.v

SP_TESTBENCH    += dlsc_stereobm_postprocess_tb.sp

V_PARAMS_DEF    += \
    DISP_BITS=6 \
    DISPARITIES=64 \
    SUB_BITS=4 \
    SUB_BITS_EXTRA=4 \
    UNIQUE_MUL=1 \
    UNIQUE_DIV=4 \
    MULT_R=3 \
    SAD_BITS=16

$(call dlsc-sim,"")
$(call dlsc-sim,"SUB_BITS=0 UNIQUE_MUL=0")
$(call dlsc-sim,"SUB_BITS=0")
$(call dlsc-sim,"UNIQUE_MUL=0")
$(call dlsc-sim,"SUB_BITS_EXTRA=0")
$(call dlsc-sim,"DISP_BITS=7 DISPARITIES=80")
$(call dlsc-sim,"MULT_R=1")

include $(DLSC_MAKEFILE_BOT)

