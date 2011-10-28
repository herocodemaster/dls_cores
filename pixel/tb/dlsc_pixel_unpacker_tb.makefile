
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel

V_DUT           += dlsc_pixel_unpacker.v

SP_TESTBENCH    += dlsc_pixel_unpacker_tb.sp

V_PARAMS_DEF    += \
    PLEN=8 \
    BPP=24 \
    FAST=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="PLEN=12"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="BPP=8"
	$(MAKE) -f $(THIS) V_PARAMS="BPP=8 PLEN=4 FAST=1"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="BPP=16"
	$(MAKE) -f $(THIS) V_PARAMS="BPP=32"

include $(DLSC_MAKEFILE_BOT)

