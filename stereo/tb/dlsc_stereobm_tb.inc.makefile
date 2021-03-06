
# meant to be included by specific _tb.makefile

DLSC_DEPENDS    += stereo opencv

SP_TESTBENCH    += dlsc_stereobm_tb.sp

C_FILES         += dlsc_stereobm_models.cpp dlsc_stereobm_models_sc.cpp

V_PARAMS_DEF    += \
    DATA=8 \
    DATAF=4 \
    DATAF_MAX=14 \
    IMG_WIDTH=128 \
    IMG_HEIGHT=32 \
    DISP_BITS=5 \
    DISPARITIES=32 \
    SAD_WINDOW=9 \
    TEXTURE=500 \
    SUB_BITS=4 \
    SUB_BITS_EXTRA=4 \
    UNIQUE_MUL=1 \
    UNIQUE_DIV=4 \
    OUT_LEFT=1 \
    OUT_RIGHT=1 \
    MULT_D=4 MULT_R=2 \
    PIPELINE_BRAM_RD=0 \
    PIPELINE_BRAM_WR=0 \
    PIPELINE_FANOUT=0 \
    PIPELINE_LUT4=0 \
    CORE_CLK_FACTOR=0.9

$(call dlsc-sim,"")
$(call dlsc-sim,"IMG_WIDTH=150 IMG_HEIGHT=33 SAD_WINDOW=13 DISP_BITS=6 DISPARITIES=39 MULT_D=1 MULT_R=3")
$(call dlsc-sim,"SUB_BITS=2 SUB_BITS_EXTRA=3")
$(call dlsc-sim,"SUB_BITS=3 SUB_BITS_EXTRA=0")
$(call dlsc-sim,"UNIQUE_MUL=0 TEXTURE=0 SUB_BITS=0")
$(call dlsc-sim,"UNIQUE_MUL=0")
$(call dlsc-sim,"TEXTURE=0")
$(call dlsc-sim,"SUB_BITS=0")
$(call dlsc-sim,"DATA=9 DATAF=6 DATAF_MAX=63")
$(call dlsc-sim,"MULT_D=1 MULT_R=1")
$(call dlsc-sim,"MULT_D=1 MULT_R=2")
$(call dlsc-sim,"MULT_D=2 MULT_R=1")
$(call dlsc-sim,"MULT_D=6 DISPARITIES=30")
$(call dlsc-sim,"OUT_LEFT=0 OUT_RIGHT=0")
$(call dlsc-sim,"OUT_LEFT=0 OUT_RIGHT=1")
$(call dlsc-sim,"OUT_LEFT=1 OUT_RIGHT=0")
$(call dlsc-sim,"CORE_CLK_FACTOR=0.1")
$(call dlsc-sim,"CORE_CLK_FACTOR=0.5")
$(call dlsc-sim,"CORE_CLK_FACTOR=1.5")
$(call dlsc-sim,"CORE_CLK_FACTOR=5.0")
$(call dlsc-sim,"UNIQUE_MUL=1 UNIQUE_DIV=2 SUB_BITS=0")
$(call dlsc-sim,"UNIQUE_MUL=3 UNIQUE_DIV=8 TEXTURE=0")
$(call dlsc-sim,"PIPELINE_BRAM_RD=1 PIPELINE_BRAM_WR=1 PIPELINE_FANOUT=1 PIPELINE_LUT4=1")
$(call dlsc-sim,"PIPELINE_BRAM_RD=1")
$(call dlsc-sim,"PIPELINE_BRAM_WR=1")
$(call dlsc-sim,"PIPELINE_FANOUT=1")
$(call dlsc-sim,"PIPELINE_LUT4=1")
$(call dlsc-sim,"IMG_WIDTH=384 IMG_HEIGHT=288 DISP_BITS=6 DISPARITIES=64 SAD_WINDOW=17 TEXTURE=1200 SUB_BITS=4 UNIQUE_MUL=1 OUT_LEFT=1 OUT_RIGHT=1 MULT_D=8 MULT_R=2")

include $(DLSC_MAKEFILE_BOT)

