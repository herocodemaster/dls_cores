
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += stereo

V_DUT           += dlsc_xsobel_core.v

SP_TESTBENCH    += dlsc_xsobel_core_tb.sp

V_PARAMS_DEF    += \
    IN_DATA=8 \
    OUT_DATA=4 \
    OUT_CLAMP=15 \
    IMG_WIDTH=128 \
    IMG_HEIGHT=32

sims:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="IMG_WIDTH=129 IMG_HEIGHT=31"
	$(MAKE) -f $(THIS) V_PARAMS="IMG_WIDTH=127 IMG_HEIGHT=33"
	$(MAKE) -f $(THIS) V_PARAMS="IN_DATA=9 OUT_DATA=7 OUT_CLAMP=125 IMG_WIDTH=253 IMG_HEIGHT=59"

include $(DLSC_MAKEFILE_BOT)

