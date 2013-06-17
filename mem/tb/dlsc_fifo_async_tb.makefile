
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += mem

V_DUT           += dlsc_fifo_async.v

SP_TESTBENCH    += dlsc_fifo_async_tb.sp

V_PARAMS_DEF    += \
    RAND_SEED=1 \
    DATA=8 \
    ADDR=4 \
    ALMOST_FULL=8 \
    ALMOST_EMPTY=8 \
    BRAM=0

$(call dlsc-sim,"")
$(call dlsc-sim,"RAND_SEED=2 DATA=13")
$(call dlsc-sim,"RAND_SEED=3 ADDR=3 ALMOST_FULL=3 ALMOST_EMPTY=6")
$(call dlsc-sim,"RAND_SEED=4 DATA=9 ADDR=5")
$(call dlsc-sim,"RAND_SEED=5 BRAM=1 ")
$(call dlsc-sim,"RAND_SEED=6 BRAM=1 DATA=13")
$(call dlsc-sim,"RAND_SEED=7 BRAM=1 ADDR=3 ALMOST_FULL=3 ALMOST_EMPTY=6")
$(call dlsc-sim,"RAND_SEED=8 BRAM=1 DATA=9 ADDR=5")
$(call dlsc-sim,"RAND_SEED=9 ALMOST_FULL=1 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=10 ALMOST_FULL=15 ALMOST_EMPTY=15")
$(call dlsc-sim,"RAND_SEED=11 ALMOST_FULL=0")
$(call dlsc-sim,"RAND_SEED=12 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=13 BRAM=1 ALMOST_FULL=1 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=14 BRAM=1 ALMOST_FULL=15 ALMOST_EMPTY=15")
$(call dlsc-sim,"RAND_SEED=15 BRAM=1 ALMOST_FULL=0")
$(call dlsc-sim,"RAND_SEED=16 BRAM=1 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=17 ALMOST_FULL=0 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=18 BRAM=1 ALMOST_FULL=0 ALMOST_EMPTY=0")

include $(DLSC_MAKEFILE_BOT)

