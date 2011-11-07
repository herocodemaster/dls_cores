
DLSC_DEPENDS    += xilinx

COREGEN_MIG     := $(HOME)/projects/work/xilinx/dlsc_sp605/coregen/dlsc_sp605_mig

V_DIRS          += $(COREGEN_MIG)/user_design/rtl
V_DIRS          += $(COREGEN_MIG)/user_design/rtl/axi
V_DIRS          += $(COREGEN_MIG)/user_design/rtl/mcb_controller
V_DIRS          += $(COREGEN_MIG)/user_design/sim

# for ddr3_model
VH_DIRS         += $(COREGEN_MIG)/user_design/sim
V_DEFINES       += x1Gb sg187E x16

ISIM_FUSE_LIBS  += secureip

