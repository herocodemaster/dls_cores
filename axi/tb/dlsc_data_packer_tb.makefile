
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel

V_DUT           += dlsc_data_packer.v

SP_TESTBENCH    += dlsc_data_packer_tb.sp

V_PARAMS_DEF    += \
    WLEN=12 \
    WORDS_ZERO=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="WLEN=7"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="WORDS_ZERO=1"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="WLEN=7 WORDS_ZERO=1"

include $(DLSC_MAKEFILE_BOT)

