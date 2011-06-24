
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += uart

V_DUT           += dlsc_uart_rx_core_test.v

SP_TESTBENCH    += dlsc_uart_rx_core_tb.sp

V_PARAMS_DEF    += \
    START=1 \
    STOP=1 \
    DATA=8 \
    PARITY=1 \
    OVERSAMPLE=16 \
    FREQ_IN=10000000 \
    FREQ_OUT=115200

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="START=2"
	$(MAKE) -f $(THIS) V_PARAMS="STOP=2"
	$(MAKE) -f $(THIS) V_PARAMS="PARITY=2"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="PARITY=0"
	$(MAKE) -f $(THIS) V_PARAMS="DATA=5"
	$(MAKE) -f $(THIS) V_PARAMS="DATA=9"
	$(MAKE) -f $(THIS) V_PARAMS="START=1 STOP=1 DATA=5 PARITY=0"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="START=2 STOP=2 DATA=9 PARITY=1"
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_OUT=1200"
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_OUT=28800"
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_OUT=250000"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_IN=15000000"
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_IN=15000000 OVERSAMPLE=8"
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_IN=100000000"
	$(MAKE) -f $(THIS) V_PARAMS="FREQ_IN=82398714 OVERSAMPLE=23"

include $(DLSC_MAKEFILE_BOT)
