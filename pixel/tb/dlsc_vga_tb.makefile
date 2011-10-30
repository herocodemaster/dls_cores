
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel axi_tlm

V_DUT           += dlsc_vga.v

SP_TESTBENCH    += dlsc_vga_tb.sp

SP_FILES        += dlsc_apb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    APB_ADDR=32 \
    AXI_ADDR=32 \
    AXI_LEN=4 \
    AXI_MOT=16 \
    BUFFER=1024 \
    MAX_H=1024 \
    MAX_V=1024 \
    HDISP=640 \
    HSYNCSTART=672 \
    HSYNCEND=760 \
    HTOTAL=792 \
    VDISP=480 \
    VSYNCSTART=490 \
    VSYNCEND=495 \
    VTOTAL=505 \
    BYTES_PER_PIXEL=3 \
    RED_POS=2 \
    GREEN_POS=1 \
    BLUE_POS=0 \
    ALPHA_POS=3 \
    FIXED_MODELINE=0 \
    FIXED_PIXEL=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""

include $(DLSC_MAKEFILE_BOT)

