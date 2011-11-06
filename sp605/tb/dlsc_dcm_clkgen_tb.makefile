
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += sp605 axi xilinx

V_DUT           += dlsc_dcm_clkgen.v

V_TESTBENCH     += dlsc_dcm_clkgen_tb.v

V_PARAMS_DEF    += \
    ADDR=32 \
    ENABLE=0 \
    CLK_IN_PERIOD=5.0 \
    CLK_DIVIDE=4 \
    CLK_MULTIPLY=2 \
    CLK_MD_MAX=4.0 \
    CLK_DIV_DIVIDE=2

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)


