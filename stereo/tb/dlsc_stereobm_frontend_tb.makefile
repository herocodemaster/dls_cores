
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += stereo

V_DUT           += dlsc_stereobm_frontend.v

SP_TESTBENCH    += dlsc_stereobm_frontend_tb.sp

V_PARAMS_DEF    += \
    DATA=8 \
    IMG_WIDTH=128 \
    IMG_HEIGHT=32 \
    DISP_BITS=6 \
    DISPARITIES=64 \
    SAD=17 \
    TEXTURE=1 \
    TEXTURE_CONST=42 \
    MULT_D=4 \
    MULT_R=4 \
    PIPELINE_WR=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="MULT_D=1 MULT_R=1"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="MULT_D=1 MULT_R=2"
	$(MAKE) -f $(THIS) V_PARAMS="MULT_D=2 MULT_R=1"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="TEXTURE=0"
	$(MAKE) -f $(THIS) V_PARAMS="PIPELINE_WR=1"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="DATA=9 IMG_WIDTH=129 IMG_HEIGHT=33 DISP_BITS=7 DISPARITIES=80 SAD=13 TEXTURE_CONST=318 MULT_D=10 MULT_R=3"

include $(DLSC_MAKEFILE_BOT)

