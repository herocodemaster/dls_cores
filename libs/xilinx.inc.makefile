
ifndef XILINX
    $(error XILINX must be set)
endif

V_DEFINES       += XILINX=1

ifdef USING_VERILOG
    V_DIRS          += $(XILINX)/verilog/src
    V_FILES         += glbl.v

    # Icarus has trouble with some Xilinx models
    # use Xilinx's ISim if Icarus isn't explicitly requested
    ifndef USING_ICARUS
        USING_ISIM      := 1
        ISIM_FUSE_LIBS  += unisims unisims_ver
        # only needed for post-place&route simulations
        #ISIM_FUSE_LIBS  += simprims simprims_ver
    else
        $(warning Using Icarus with Xilinx simulation models is not recommended)
        V_DIRS          += $(XILINX)/verilog/src/unisims
    endif
endif

ifdef USING_VERILATOR
    V_DIRS          += $(XILINX)/verilog/src/unisims
endif

