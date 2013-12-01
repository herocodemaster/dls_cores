
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += alu

V_DUT           += dlsc_divu.v

V_TESTBENCH     += dlsc_divu_tb.v

V_PARAMS_DEF    += \
    CYCLES=1 \
    NB=8 \
    DB=8 \
    QB=8 \
    NFB=0 \
    DFB=0 \
    QFB=0

## divu_pipe tests ##
# base
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1")
# NB sweep
$(call dlsc-sim,"NB=1 DB=8 QB=8 CYCLES=1")
$(call dlsc-sim,"NB=7 DB=8 QB=8 CYCLES=1")
$(call dlsc-sim,"NB=9 DB=8 QB=8 CYCLES=1")
$(call dlsc-sim,"NB=16 DB=8 QB=8 CYCLES=1")
# DB sweep
$(call dlsc-sim,"NB=8 DB=1 QB=8 CYCLES=1")
$(call dlsc-sim,"NB=8 DB=7 QB=8 CYCLES=1")
$(call dlsc-sim,"NB=8 DB=9 QB=8 CYCLES=1")
$(call dlsc-sim,"NB=8 DB=16 QB=8 CYCLES=1")
# QB sweep
$(call dlsc-sim,"NB=8 DB=8 QB=1 CYCLES=1")
$(call dlsc-sim,"NB=8 DB=8 QB=7 CYCLES=1")
$(call dlsc-sim,"NB=8 DB=8 QB=9 CYCLES=1")
$(call dlsc-sim,"NB=8 DB=8 QB=16 CYCLES=1")
# FB sweep
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 NFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 NFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 DFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 DFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 DFB=8")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 QFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 QFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 QFB=8")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 NFB=1 DFB=1 QFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 NFB=7 DFB=7 QFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=1 NFB=8 DFB=8 QFB=8")

## divu_seq tests ##
# base
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8")
# NB sweep
$(call dlsc-sim,"NB=1 DB=8 QB=8 CYCLES=8")
$(call dlsc-sim,"NB=7 DB=8 QB=8 CYCLES=8")
$(call dlsc-sim,"NB=9 DB=8 QB=8 CYCLES=8")
$(call dlsc-sim,"NB=16 DB=8 QB=8 CYCLES=8")
# DB sweep
$(call dlsc-sim,"NB=8 DB=1 QB=8 CYCLES=8")
$(call dlsc-sim,"NB=8 DB=7 QB=8 CYCLES=8")
$(call dlsc-sim,"NB=8 DB=9 QB=8 CYCLES=8")
$(call dlsc-sim,"NB=8 DB=16 QB=8 CYCLES=8")
# QB sweep
$(call dlsc-sim,"NB=8 DB=8 QB=2 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=8 QB=7 CYCLES=7")
$(call dlsc-sim,"NB=8 DB=8 QB=9 CYCLES=9")
$(call dlsc-sim,"NB=8 DB=8 QB=16 CYCLES=16")
# FB sweep
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 NFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 NFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 DFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 DFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 DFB=8")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 QFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 QFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 QFB=8")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 NFB=1 DFB=1 QFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 NFB=7 DFB=7 QFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=8 NFB=8 DFB=8 QFB=8")
# CYCLES sweep
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=9")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=10")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=30")

## divu_hybrid tests ##
# base
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2")
# NB sweep
$(call dlsc-sim,"NB=1 DB=8 QB=8 CYCLES=2")
$(call dlsc-sim,"NB=7 DB=8 QB=8 CYCLES=2")
$(call dlsc-sim,"NB=9 DB=8 QB=8 CYCLES=2")
$(call dlsc-sim,"NB=16 DB=8 QB=8 CYCLES=2")
# DB sweep
$(call dlsc-sim,"NB=8 DB=1 QB=8 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=7 QB=8 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=9 QB=8 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=16 QB=8 CYCLES=2")
# QB sweep
$(call dlsc-sim,"NB=8 DB=8 QB=3 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=8 QB=7 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=8 QB=9 CYCLES=2")
$(call dlsc-sim,"NB=8 DB=8 QB=16 CYCLES=2")
# FB sweep
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 NFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 NFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 DFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 DFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 DFB=8")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 QFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 QFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 QFB=8")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 NFB=1 DFB=1 QFB=1")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 NFB=7 DFB=7 QFB=7")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=2 NFB=8 DFB=8 QFB=8")
# CYCLES sweep
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=3")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=4")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=5")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=6")
$(call dlsc-sim,"NB=8 DB=8 QB=8 CYCLES=7")

include $(DLSC_MAKEFILE_BOT)

