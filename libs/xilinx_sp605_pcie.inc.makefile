
DLSC_DEPENDS    += xilinx

COREGEN_PCIE    := $(HOME)/projects/work/xilinx/dlsc_sp605/coregen/dlsc_sp605_pcie

V_DIRS          += $(COREGEN_PCIE)/source
V_DIRS          += $(COREGEN_PCIE)/simulation/dsport
V_DIRS          += $(COREGEN_PCIE)/example_design

ISIM_FUSE_LIBS  += unisims_ver secureip

