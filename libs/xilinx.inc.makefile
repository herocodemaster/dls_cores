
ifndef XILINX
    $(error XILINX must be set)
endif

V_DIRS          += $(XILINX)/verilog/src
V_FILES         += glbl.v

V_DEFINES       += XILINX=1

ISIM_FUSE_LIBS  += unisims unisims_ver

ifdef USING_VERILOG
    # Icarus has trouble with some Xilinx models
    # use Xilinx's ISim if Icarus isn't explicitly requested
    ifndef USING_ICARUS
        USING_ISIM      := 1
    else
        $(warning Using Icarus with Xilinx simulation models is not recommended)
        V_DIRS          += $(XILINX)/verilog/src/unisims
    endif
endif

