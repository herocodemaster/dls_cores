
V_DIRS          += $(XILINX)/verilog/src $(XILINX)/verilog/src/unisims

V_FILES         += glbl.v

V_DEFINES       += XILINX=1

ISIM_FUSE_FLAGS += -L unisims

ifdef USING_VERILOG
    # Icarus doesn't much care for Xilinx simulation models..
    # use Xilinx's ISim instead.
    ifdef USING_ICARUS
        undefine USING_ICARUS
    endif
    USING_ISIM      := 1
endif

