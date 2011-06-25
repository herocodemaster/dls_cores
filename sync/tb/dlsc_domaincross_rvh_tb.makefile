
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sync

V_DUT           += dlsc_domaincross_rvh_test.v

SP_TESTBENCH    += dlsc_domaincross_rvh_tb.sp

V_PARAMS_DEF    += \
    DATA=8 \
    IN_CLK=10.0 \
    OUT_CLK=11.3

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="DATA=13"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="IN_CLK=10.0 OUT_CLK=10.0"
	$(MAKE) -f $(THIS) V_PARAMS="IN_CLK=10.0 OUT_CLK=99.3"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="IN_CLK=101.1 OUT_CLK=10.0"
	$(MAKE) -f $(THIS) V_PARAMS="IN_CLK=100.0 OUT_CLK=1.0"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="IN_CLK=1.0 OUT_CLK=100.0"

include $(DLSC_MAKEFILE_BOT)

