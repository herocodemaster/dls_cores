
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += stereo opencv

V_DUT           += dlsc_stereobm_prefiltered.v

V_TESTBENCH     += dlsc_stereobm_tbv.v

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
    PIPELINE_LUT4=0

V_DEFINES       += \
    FILE_IN_LEFT='"$(CWD)/data/_gen/tbv_in_left.memh"' \
    FILE_IN_RIGHT='"$(CWD)/data/_gen/tbv_in_right.memh"' \
    FILE_DISP='"$(CWD)/data/_gen/tbv_disp.memh"' \
    FILE_VALID='"$(CWD)/data/_gen/tbv_valid.memh"' \
    FILE_FILTERED='"$(CWD)/data/_gen/tbv_filtered.memh"' \
    FILE_LEFT='"$(CWD)/data/_gen/tbv_left.memh"' \
    FILE_RIGHT='"$(CWD)/data/_gen/tbv_right.memh"'

# executable model
DLSC_STEREOBM_MODEL := $(CWD)/_gen/dlsc_stereobm_model.bin

$(DLSC_STEREOBM_MODEL) : $(CWD)/dlsc_stereobm_models_program.cpp $(CWD)/dlsc_stereobm_models.cpp
	@echo building $(notdir $@)
	@[ -d $(@D) ] || mkdir -p $(@D)
	@$(CXX) -O2 -o $@ -I/usr/include/opencv $^ -lcv -lcvaux -lhighgui -lboost_program_options

# TODO: need to parameterize memh generation
.PHONY: gen_memh
gen_memh: $(DLSC_STEREOBM_MODEL)
	@echo creating expected-results files..
	@[ -d $(CWD)/data/_gen ] || mkdir -p $(CWD)/data/_gen
	@$(DLSC_STEREOBM_MODEL) \
        --left $(CWD)/data/conesq.im2.ppm \
        --right $(CWD)/data/conesq.im6.ppm \
        --output $(CWD)/data/_gen/tbv \
        --readmemh=1 \
        --xsobel=1 \
        --data-max=14 \
        --disparities=32 \
        --sad-window=9 \
        --texture=500 \
        --sub-bits=4 \
        --sub-bits-extra=4 \
        --unique-mul=1 \
        --unique-div=4 \
        --width=128 \
        --height=32 \
        --scale=1

gen: gen_memh

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

