
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += rvh

V_DUT           += dlsc_rowbuffer_splitter.v

SP_TESTBENCH    += dlsc_rowbuffer_splitter_tb.sp

V_PARAMS_DEF    += \
    ROW_WIDTH=128 \
    BUF_DEPTH=128 \
    ROWS=3 \
    DATA=16 \
    IN_CLK=10 \
    OUT_CLK=31.7

$(call dlsc-sim,"")
$(call dlsc-sim,"DATA=9")
$(call dlsc-sim,"ROWS=1")
$(call dlsc-sim,"ROWS=1 IN_CLK=10 OUT_CLK=10")
$(call dlsc-sim,"ROWS=1 IN_CLK=11.3 OUT_CLK=100")
$(call dlsc-sim,"ROWS=1 IN_CLK=100 OUT_CLK=11.3")
$(call dlsc-sim,"IN_CLK=11.3 OUT_CLK=100")
$(call dlsc-sim,"IN_CLK=100 OUT_CLK=11.3")
$(call dlsc-sim,"IN_CLK=10 OUT_CLK=10")
$(call dlsc-sim,"BUF_DEPTH=129")
$(call dlsc-sim,"BUF_DEPTH=256")
$(call dlsc-sim,"ROW_WIDTH=127 BUF_DEPTH=127")
$(call dlsc-sim,"ROW_WIDTH=127 BUF_DEPTH=139")

include $(DLSC_MAKEFILE_BOT)

