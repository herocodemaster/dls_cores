
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu xilinx

V_DUT           += dlsc_mult.v

V_TESTBENCH     += dlsc_mult_tb.v

V_PARAMS_DEF    += \
    DEVICE=GENERIC \
    SIGNED=0 \
    DATA0=16 \
    DATA1=16 \
    OUT=24 \
    DATAF0=0 \
    DATAF1=0 \
    OUTF=0 \
    CLAMP=0 \
    PIPELINE=4

$(call dlsc-sim,"")
$(call dlsc-sim,"DATA0=24")
$(call dlsc-sim,"DATA1=24")
$(call dlsc-sim,"OUT=12")
$(call dlsc-sim,"OUT=32")
$(call dlsc-sim,"OUT=48 OUTF=16")

$(call dlsc-sim,"DATA0=4 DATA1=4 OUT=32")
$(call dlsc-sim,"DATA0=4 DATA1=4 OUT=32 SIGNED=1")

$(call dlsc-sim,"PIPELINE=0")
$(call dlsc-sim,"PIPELINE=1")
$(call dlsc-sim,"PIPELINE=2")
$(call dlsc-sim,"PIPELINE=3")
$(call dlsc-sim,"PIPELINE=4")
$(call dlsc-sim,"PIPELINE=5")
$(call dlsc-sim,"PIPELINE=6")

$(call dlsc-sim,"CLAMP=1")
$(call dlsc-sim,"CLAMP=1 SIGNED=1")
$(call dlsc-sim,"SIGNED=1")

$(call dlsc-sim,"DATAF0=4")
$(call dlsc-sim,"DATAF0=16")
$(call dlsc-sim,"DATAF1=4")
$(call dlsc-sim,"DATAF1=16")
$(call dlsc-sim,"OUTF=4")
$(call dlsc-sim,"OUTF=15")
$(call dlsc-sim,"DATAF0=4 DATAF1=8 OUTF=2")
$(call dlsc-sim,"DATAF0=4 DATAF1=8 OUTF=24")

$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=0")
$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=1")
$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=2")
$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=3")
$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=4")
$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=5")
$(call dlsc-sim,"DEVICE=SPARTAN6 PIPELINE=6")

$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=0")
$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=1")
$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=2")
$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=3")
$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=4")
$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=5")
$(call dlsc-sim,"DEVICE=SPARTAN6 SIGNED=1 PIPELINE=6")

$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=1")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=2")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=3")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=4")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=5")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=6")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 PIPELINE=7")

$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=1")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=2")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=3")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=4")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=5")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=6")
$(call dlsc-sim,"DEVICE=SPARTAN6 CLAMP=1 SIGNED=1 PIPELINE=7")

include $(DLSC_MAKEFILE_BOT)

