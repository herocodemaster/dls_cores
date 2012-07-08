
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel axi_tlm csr_tlm

V_DUT           += dlsc_pxdma_test.v

SP_TESTBENCH    += dlsc_pxdma_test_tb.sp

SP_FILES        += dlsc_csr_tlm_master_32b.sp
SP_FILES        += dlsc_axi4lb_tlm_slave_32b.sp

V_PARAMS_DEF    += \
    AXI_ASYNC=0 \
    IN_ASYNC=0 \
    OUT_ASYNC=0 \
    READERS=1 \
    OUT_BUFFER=1024 \
    MAX_H=1024 \
    MAX_V=1024 \
    BYTES_PER_PIXEL=3 \
    AXI_ADDR=32 \
    AXI_LEN=4 \
    AXI_MOT=16 \
    CSR_ADDR=32

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="AXI_ASYNC=1"
	$(MAKE) -f $(THIS) V_PARAMS="IN_ASYNC=1"
	$(MAKE) -f $(THIS) V_PARAMS="OUT_ASYNC=1"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="AXI_ASYNC=1 IN_ASYNC=1 OUT_ASYNC=1"
	$(MAKE) -f $(THIS) V_PARAMS="BYTES_PER_PIXEL=1"
	$(MAKE) -f $(THIS) V_PARAMS="BYTES_PER_PIXEL=2"
	$(MAKE) -f $(THIS) V_PARAMS="BYTES_PER_PIXEL=4"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="READERS=2"
	$(MAKE) -f $(THIS) V_PARAMS="READERS=3"
	$(MAKE) -f $(THIS) V_PARAMS="READERS=4"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="READERS=4 AXI_ASYNC=1 IN_ASYNC=1 OUT_ASYNC=1"

include $(DLSC_MAKEFILE_BOT)

