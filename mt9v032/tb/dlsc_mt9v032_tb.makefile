
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += mt9v032

V_DUT           += dlsc_mt9v032.v

V_TESTBENCH     += dlsc_mt9v032_tb.v

V_PARAMS_DEF    += \
    CAMERAS=1 \
    SWAP=0 \
    APB_ADDR=32 \
    HDISP=752 \
    VDISP=480 \
    FIFO_ADDR=4

sims3:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)


