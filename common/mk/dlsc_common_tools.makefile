
#
# External tools
#

PERL        := perl

# VerilogPerl
ifndef VERILOGPERL
    $(error VERILOGPERL must be set)
endif
VHIER       := $(VERILOGPERL)/vhier

# Verilator
ifdef USING_VERILATOR
    TBWRAPPER   := $(PERL) $(DLSC_COMMON)/tools/dlsc_tbwrapper.pl

    ifndef VERILATOR_ROOT
        $(error VERILATOR_ROOT must be set)
    endif
    VERILATOR   := $(VERILATOR_ROOT)/bin/verilator
endif

# SystemC
ifdef USING_SYSTEMC

    # SystemC
    ifndef SYSTEMC
        $(error SYSTEMC must be set)
    endif
    ifndef SYSTEMC_ARCH
        $(error SYSTEMC_ARCH must be set)
    endif

    # SystemPerl
    ifndef SYSTEMPERL
        $(error SYSTEMPERL must be set)
    endif
    SP_PREPROC  := $(SYSTEMPERL)/sp_preproc
    VCOVERAGE   := $(SYSTEMPERL)/vcoverage

endif

# Icarus
ifdef USING_ICARUS
    ICARUS_IVERILOG := iverilog
    ICARUS_VVP  := vvp
endif

# Xilinx ISim
ifdef USING_ISIM
    ifndef XILINX
        $(error XILINX must be set)
    endif

    ISIM_VLOGCOMP := vlogcomp
    ISIM_FUSE   := fuse
endif

GTKWAVE     := gtkwave

