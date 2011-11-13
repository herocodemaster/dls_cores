
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel axi_tlm

V_DUT           += dlsc_pxdma_test.v

SP_TESTBENCH    += dlsc_pxdma_test_tb.sp

SP_FILES        += dlsc_apb_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    APB_ADDR=32 \
    AXI_ADDR=32 \
    AXI_LEN=4 \
    AXI_MOT=16 \
    MAX_H=1024 \
    MAX_V=1024 \
    BYTES_PER_PIXEL=3 \
    READERS=1 \
    OUT_BUFFER=1024 \
    IN_ASYNC=0 \
    OUT_ASYNC=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="IN_ASYNC=1"
	$(MAKE) -f $(THIS) V_PARAMS="OUT_ASYNC=1"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="IN_ASYNC=1 OUT_ASYNC=1"
	$(MAKE) -f $(THIS) V_PARAMS="BYTES_PER_PIXEL=1"
	$(MAKE) -f $(THIS) V_PARAMS="BYTES_PER_PIXEL=2"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="BYTES_PER_PIXEL=4"
	$(MAKE) -f $(THIS) V_PARAMS="READERS=2"
	$(MAKE) -f $(THIS) V_PARAMS="READERS=3"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="READERS=4"
	$(MAKE) -f $(THIS) V_PARAMS="READERS=4 IN_ASYNC=1 OUT_ASYNC=1"

include $(DLSC_MAKEFILE_BOT)

