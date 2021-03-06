
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += mem

V_DUT           += dlsc_fifo_async.v

SP_TESTBENCH    += dlsc_fifo_async_tb.sp

V_PARAMS_DEF    += \
    RAND_SEED=1 \
    WR_CYCLES=1 \
    RD_CYCLES=1 \
    WR_PIPELINE=0 \
    RD_PIPELINE=0 \
    DATA=16 \
    ADDR=4 \
    ALMOST_FULL=8 \
    ALMOST_EMPTY=8 \
    FREE=1 \
    COUNT=1 \
    BRAM=0

$(call dlsc-sim,"RAND_SEED=24 BRAM=0")
$(call dlsc-sim,"RAND_SEED=25 BRAM=1")

$(call dlsc-sim,"RAND_SEED=27 BRAM=0 WR_CYCLES=2")
$(call dlsc-sim,"RAND_SEED=28 BRAM=0 RD_CYCLES=2")
$(call dlsc-sim,"RAND_SEED=29 BRAM=0 WR_CYCLES=2 RD_CYCLES=2")
$(call dlsc-sim,"RAND_SEED=30 BRAM=0 WR_PIPELINE=1")
$(call dlsc-sim,"RAND_SEED=31 BRAM=0 RD_PIPELINE=1")
$(call dlsc-sim,"RAND_SEED=32 BRAM=0 WR_PIPELINE=1 RD_PIPELINE=1")
$(call dlsc-sim,"RAND_SEED=33 BRAM=0 WR_PIPELINE=1 RD_PIPELINE=1 WR_CYCLES=2 RD_CYCLES=2")

$(call dlsc-sim,"RAND_SEED=35 BRAM=1 WR_CYCLES=2")
$(call dlsc-sim,"RAND_SEED=36 BRAM=1 RD_CYCLES=2")
$(call dlsc-sim,"RAND_SEED=37 BRAM=1 WR_CYCLES=2 RD_CYCLES=2")
$(call dlsc-sim,"RAND_SEED=38 BRAM=1 WR_PIPELINE=1")
$(call dlsc-sim,"RAND_SEED=39 BRAM=1 RD_PIPELINE=1")
$(call dlsc-sim,"RAND_SEED=40 BRAM=1 WR_PIPELINE=1 RD_PIPELINE=1")
$(call dlsc-sim,"RAND_SEED=41 BRAM=1 WR_PIPELINE=1 RD_PIPELINE=1 WR_CYCLES=2 RD_CYCLES=2")

$(call dlsc-sim,"RAND_SEED=43 BRAM=0 DATA=1")
$(call dlsc-sim,"RAND_SEED=44 BRAM=0 DATA=63")
$(call dlsc-sim,"RAND_SEED=45 BRAM=0 ADDR=2 ALMOST_FULL=1 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=46 BRAM=0 ADDR=6")
$(call dlsc-sim,"RAND_SEED=47 BRAM=0 ADDR=9")
$(call dlsc-sim,"RAND_SEED=48 BRAM=0 ALMOST_FULL=0")
$(call dlsc-sim,"RAND_SEED=49 BRAM=0 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=50 BRAM=0 FREE=0")
$(call dlsc-sim,"RAND_SEED=51 BRAM=0 COUNT=0")
$(call dlsc-sim,"RAND_SEED=52 BRAM=0 ALMOST_FULL=0 ALMOST_EMPTY=0 FREE=0 COUNT=0")
$(call dlsc-sim,"RAND_SEED=53 BRAM=0 ALMOST_FULL=1 ALMOST_EMPTY=15")
$(call dlsc-sim,"RAND_SEED=54 BRAM=0 ALMOST_FULL=15 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=55 BRAM=0 ALMOST_FULL=3 ALMOST_EMPTY=6")

$(call dlsc-sim,"RAND_SEED=57 BRAM=1 DATA=1")
$(call dlsc-sim,"RAND_SEED=58 BRAM=1 DATA=63")
$(call dlsc-sim,"RAND_SEED=59 BRAM=1 ADDR=2 ALMOST_FULL=1 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=60 BRAM=1 ADDR=6")
$(call dlsc-sim,"RAND_SEED=61 BRAM=1 ADDR=9")
$(call dlsc-sim,"RAND_SEED=62 BRAM=1 ALMOST_FULL=0")
$(call dlsc-sim,"RAND_SEED=63 BRAM=1 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=64 BRAM=1 FREE=0")
$(call dlsc-sim,"RAND_SEED=65 BRAM=1 COUNT=0")
$(call dlsc-sim,"RAND_SEED=66 BRAM=1 ALMOST_FULL=0 ALMOST_EMPTY=0 FREE=0 COUNT=0")
$(call dlsc-sim,"RAND_SEED=67 BRAM=1 ALMOST_FULL=1 ALMOST_EMPTY=15")
$(call dlsc-sim,"RAND_SEED=68 BRAM=1 ALMOST_FULL=15 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=69 BRAM=1 ALMOST_FULL=3 ALMOST_EMPTY=6")

$(call dlsc-sim,"RAND_SEED=71 BRAM=0 RD_PIPELNE=1 DATA=1")
$(call dlsc-sim,"RAND_SEED=72 BRAM=0 RD_PIPELNE=1 DATA=63")
$(call dlsc-sim,"RAND_SEED=73 BRAM=0 RD_PIPELNE=1 ADDR=2 ALMOST_FULL=1 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=74 BRAM=0 RD_PIPELNE=1 ADDR=6")
$(call dlsc-sim,"RAND_SEED=75 BRAM=0 RD_PIPELNE=1 ADDR=9")
$(call dlsc-sim,"RAND_SEED=76 BRAM=0 RD_PIPELNE=1 ALMOST_FULL=0")
$(call dlsc-sim,"RAND_SEED=77 BRAM=0 RD_PIPELNE=1 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=78 BRAM=0 RD_PIPELNE=1 FREE=0")
$(call dlsc-sim,"RAND_SEED=79 BRAM=0 RD_PIPELNE=1 COUNT=0")
$(call dlsc-sim,"RAND_SEED=80 BRAM=0 RD_PIPELNE=1 ALMOST_FULL=0 ALMOST_EMPTY=0 FREE=0 COUNT=0")
$(call dlsc-sim,"RAND_SEED=81 BRAM=0 RD_PIPELNE=1 ALMOST_FULL=1 ALMOST_EMPTY=15")
$(call dlsc-sim,"RAND_SEED=82 BRAM=0 RD_PIPELNE=1 ALMOST_FULL=15 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=83 BRAM=0 RD_PIPELNE=1 ALMOST_FULL=3 ALMOST_EMPTY=6")

$(call dlsc-sim,"RAND_SEED=85 BRAM=1 WR_PIPELINE=1 DATA=1")
$(call dlsc-sim,"RAND_SEED=86 BRAM=1 WR_PIPELINE=1 DATA=63")
$(call dlsc-sim,"RAND_SEED=87 BRAM=1 WR_PIPELINE=1 ADDR=2 ALMOST_FULL=1 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=88 BRAM=1 WR_PIPELINE=1 ADDR=6")
$(call dlsc-sim,"RAND_SEED=89 BRAM=1 WR_PIPELINE=1 ADDR=9")
$(call dlsc-sim,"RAND_SEED=90 BRAM=1 WR_PIPELINE=1 ALMOST_FULL=0")
$(call dlsc-sim,"RAND_SEED=91 BRAM=1 WR_PIPELINE=1 ALMOST_EMPTY=0")
$(call dlsc-sim,"RAND_SEED=92 BRAM=1 WR_PIPELINE=1 FREE=0")
$(call dlsc-sim,"RAND_SEED=93 BRAM=1 WR_PIPELINE=1 COUNT=0")
$(call dlsc-sim,"RAND_SEED=94 BRAM=1 WR_PIPELINE=1 ALMOST_FULL=0 ALMOST_EMPTY=0 FREE=0 COUNT=0")
$(call dlsc-sim,"RAND_SEED=95 BRAM=1 WR_PIPELINE=1 ALMOST_FULL=1 ALMOST_EMPTY=15")
$(call dlsc-sim,"RAND_SEED=96 BRAM=1 WR_PIPELINE=1 ALMOST_FULL=15 ALMOST_EMPTY=1")
$(call dlsc-sim,"RAND_SEED=97 BRAM=1 WR_PIPELINE=1 ALMOST_FULL=3 ALMOST_EMPTY=6")

$(call dlsc-sim,"RAND_SEED=99 BRAM=0 RD_PIPELINE=1 ADDR=4 DATA=1")
$(call dlsc-sim,"RAND_SEED=100 BRAM=0 RD_PIPELINE=1 ADDR=5 DATA=1")
$(call dlsc-sim,"RAND_SEED=101 BRAM=0 RD_PIPELINE=1 ADDR=6 DATA=1")
$(call dlsc-sim,"RAND_SEED=102 BRAM=0 RD_PIPELINE=1 ADDR=7 DATA=1")
$(call dlsc-sim,"RAND_SEED=103 BRAM=0 RD_PIPELINE=1 ADDR=4 DATA=8")
$(call dlsc-sim,"RAND_SEED=104 BRAM=0 RD_PIPELINE=1 ADDR=5 DATA=8")
$(call dlsc-sim,"RAND_SEED=105 BRAM=0 RD_PIPELINE=1 ADDR=6 DATA=8")
$(call dlsc-sim,"RAND_SEED=106 BRAM=0 RD_PIPELINE=1 ADDR=7 DATA=8")
$(call dlsc-sim,"RAND_SEED=107 BRAM=0 RD_PIPELINE=1 ADDR=4 DATA=16")
$(call dlsc-sim,"RAND_SEED=108 BRAM=0 RD_PIPELINE=1 ADDR=5 DATA=16")
$(call dlsc-sim,"RAND_SEED=109 BRAM=0 RD_PIPELINE=1 ADDR=6 DATA=16")
$(call dlsc-sim,"RAND_SEED=110 BRAM=0 RD_PIPELINE=1 ADDR=7 DATA=16")
$(call dlsc-sim,"RAND_SEED=111 BRAM=0 RD_PIPELINE=1 ADDR=4 DATA=32")
$(call dlsc-sim,"RAND_SEED=112 BRAM=0 RD_PIPELINE=1 ADDR=5 DATA=32")
$(call dlsc-sim,"RAND_SEED=113 BRAM=0 RD_PIPELINE=1 ADDR=6 DATA=32")
$(call dlsc-sim,"RAND_SEED=114 BRAM=0 RD_PIPELINE=1 ADDR=7 DATA=32")
$(call dlsc-sim,"RAND_SEED=115 BRAM=0 RD_PIPELINE=1 ADDR=4 DATA=64")
$(call dlsc-sim,"RAND_SEED=116 BRAM=0 RD_PIPELINE=1 ADDR=5 DATA=64")
$(call dlsc-sim,"RAND_SEED=117 BRAM=0 RD_PIPELINE=1 ADDR=6 DATA=64")
$(call dlsc-sim,"RAND_SEED=118 BRAM=0 RD_PIPELINE=1 ADDR=7 DATA=64")

include $(DLSC_MAKEFILE_BOT)

