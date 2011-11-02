# 
# Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#   - Redistributions of source code must retain the above copyright notice,
#     this list of conditions and the following disclaimer.
#   - Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#   - The name of the author may not be used to endorse or promote products
#     derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#


#
# SystemC (Verilator) or Verilog (Icarus/ISim)?
#

ifneq (,$(SP_TESTBENCH))
    USING_SYSTEMC   := 1
    V_DEFINES       += VERILATOR=1
    TESTBENCH       := $(call dlsc-base,$(SP_TESTBENCH))
endif
ifneq (,$(V_TESTBENCH))
    USING_VERILOG   := 1
    V_DEFINES       += VERILOG=1
    TESTBENCH       := $(call dlsc-base,$(V_TESTBENCH))
endif


#
# Verilog parameters
#

# merge V_PARAMS and V_PARAMS_DEF (V_PARAMS takes precedence)

V_PARAMSI := $(V_PARAMS)

V_PARAMS_LHS := $(patsubst __EQUALS__%,,$(subst =, __EQUALS__,$(V_PARAMS)))

define V_PARAMSI_template
    LHS := $(patsubst __EQUALS__%,,$(subst =, __EQUALS__,$(1)))
    ifneq (,$$(filter-out $$(V_PARAMS_LHS),$$(LHS)))
        V_PARAMSI += $(1)
    endif
endef

$(foreach d,$(V_PARAMS_DEF),$(eval $(call V_PARAMSI_template,$(d))))

V_PARAMSI := $(sort $(V_PARAMSI))


#
# Change to _work directory
#

# based on: http://mad-scientist.net/make/multi-arch.html

# looks like: _work/_{testbench}__{md5sum(params)}/


WORKROOT    := $(DLSC_WORKROOT)
ifeq (,$(WORKROOT))
    WORKROOT    := $(CWD)/_work
endif
WORKDIR_PREFIX := $(WORKROOT)/_$(TESTBENCH)
WORKDIR     := $(WORKDIR_PREFIX)__$(call dlsc-md5sum,$(V_PARAMSI))
OBJDIR      := $(WORKDIR)/_objdir

ifeq (,$(filter _%,$(notdir $(CURDIR))))
# *****************************************************************************
# not in work dir yet; need to change to it

MAKETARGET = $(MAKE) --no-print-directory -C $@ -f $(THIS) CWD_TOP=$(CURDIR) $(MAKECMDGOALS)

.PHONY: $(WORKDIR)
$(WORKDIR):
	+@[ -d $@ ] || mkdir -p $@
	+@$(MAKETARGET)

Makefile : ;
%.mk :: ;
%.makefile :: ;

% :: $(WORKDIR) ; @:

.PHONY: clean
clean:
	rm -rf $(WORKDIR_PREFIX)__*

# remove everything except the .bin files
.PHONY: objclean
objclean:
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.sp
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.h
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.cpp
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.o
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.d
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.mk
	rm -f $(WORKDIR_PREFIX)__*/_objdir/*.dat

.PHONY: sims_summary
sims_summary: | sims0 sims1 sims2 sims3
	@echo "\n\n                                   *** Results for $(TESTBENCH) ***\n"
	@cd $(WORKROOT) && grep -n "assertions" _$(TESTBENCH)_*/*.log
	@echo "\n"

.PHONY: summary
summary:
	@echo "\n\n                                   *** Results for $(TESTBENCH) ***\n"
	@cd $(WORKROOT) && grep -n "assertions" _$(TESTBENCH)_*/*.log
	@echo "\n"

else
# *****************************************************************************
# somewhere in work dir (may or may not be objdir); perform common tasks


#
# Include dependencies
#

dlsc-find-dep = $(realpath $(firstword $(wildcard $(DLSC_ROOT)/*/$(1).inc.makefile)))

define DLSC_DEPENDS_template
    ifndef $(1)_included
        $(1)_included := 1
        CMF := $(call dlsc-find-dep,$(1))
        CWD := $$(call dlsc-dir,$$(CMF))
        DLSC_DEPENDS := 
        include $$(CMF)
        $$(foreach d,$$(DLSC_DEPENDS),$$(eval $$(call DLSC_DEPENDS_template,$$(d))))
    endif
endef

# top-level dependencies
$(foreach d,$(DLSC_DEPENDS),$(eval $(call DLSC_DEPENDS_template,$(d))))

# reset CWD
# (points to where we were originally invoked - e.g. the testbench directory)
CWD := $(CWD_TOP)


#
# Icarus or ISim?
#

# (handle this stuff after loading dependencies, in case a dependency
#  (e.g. xilinx.inc) specifies a particular simulator)

ifdef USING_VERILOG
    ifndef USING_ISIM
        USING_ICARUS    := 1
        V_DEFINES       += ICARUS=1
    else
        USING_ISIM      := 1
        V_DEFINES       += ISIM=1 XILINX=1
    endif
endif

ifndef USING_ISIM
    # Verilator and Icarus support $clog2, but not constant functions
    # ISE and ISim are the opposite
    V_DEFINES   += USE_CLOG2=1
endif


#
# Testbench
#

DEFINES     += DLSC_TB=$(TESTBENCH)

ifdef USING_SYSTEMC
SP_FILES    += $(SP_TESTBENCH)
C_DEFINES   += DLSC_DUT=V$(call dlsc-base,$(V_DUT))_tbwrapper
V_DEFINES   += DLSC_DPI_PATH=$(call dlsc-base,$(V_DUT))_tbwrapper
endif
ifdef USING_VERILOG
V_DEFINES   += DLSC_DUT=$(call dlsc-base,$(V_DUT))
endif


#
# Simulation results
#

LOG_FILE    := $(WORKDIR)/$(TESTBENCH).log
COV_FILE    := $(WORKDIR)/$(TESTBENCH).cov
LXT_FILE    := $(WORKDIR)/$(TESTBENCH).lxt
VCD_FILE    := $(WORKDIR)/$(TESTBENCH).vcd

.PRECIOUS: $(LOG_FILE) $(COV_FILE) $(LXT_FILE) $(VCD_FILE)


#
# Verilog
#

DEFINES     += $(addprefix PARAM_,$(V_PARAMSI))

V_DIRS      += $(WORKDIR)
V_DIRS      := $(sort $(V_DIRS))
V_FLAGS     += $(addprefix -y ,$(V_DIRS))

VH_DIRS     := $(sort $(VH_DIRS))
V_FLAGS     += $(addprefix +incdir+,$(VH_DIRS))

vpath %.v $(V_DIRS)
vpath %.vh $(VH_DIRS)

V_DEFINES   += $(DEFINES)
V_DEFINES   := $(sort $(V_DEFINES))
V_FLAGS     += $(addprefix -D,$(V_DEFINES))

V_DUT       := $(sort $(V_DUT))

ifdef USING_SYSTEMC
V_FILES     += $(V_DUT:.v=_tbwrapper.v)
endif
ifdef USING_VERILOG
V_FILES     += $(V_TESTBENCH)
endif

V_FILES     := $(sort $(V_FILES))
V_FILES_MK  := $(patsubst %.v,V%_classes.mk,$(V_FILES))


#
# SystemPerl
#

SP_FILES    := $(sort $(SP_FILES))
SC_FILES    := $(sort $(SC_FILES))
SCH_FILES   := $(sort $(SCH_FILES))

SP_DIRS     := $(sort $(SP_DIRS))
SC_DIRS     := $(sort $(SC_DIRS))


ifeq (,$(filter _objdir%,$(notdir $(CURDIR))))
# *****************************************************************************
# not in objdir yet; need to create prereqs


#
# Verilog DUT
#

%_tbwrapper.v : %.v
	@echo creating $(notdir $@)
	@$(TBWRAPPER) $(V_FLAGS) -i $< -o $@ --module-suffix _tbwrapper --define-prefix PARAM_


#
# Verilator
#

VERILATOR_FLAGS += $(V_FLAGS)

ifdef USING_SYSTEMC

V_FILES_MK      := $(patsubst %.v,$(OBJDIR)/V%_classes.mk,$(V_FILES))

$(OBJDIR)/V%_classes.mk : %.v | $(OBJDIR)
	@echo verilating $(notdir $<)
	@$(VERILATOR) $(VERILATOR_FLAGS) -MMD --sp --coverage --trace -Mdir $(OBJDIR) $<

.PHONY: verilator
verilator: $(V_FILES_MK)

D_FILES     := $(wildcard $(patsubst %.v,$(OBJDIR)/V%*.d,$(V_FILES)))

-include $(D_FILES)

else

.PHONY: verilator
verilator:

endif

.PHONY: lint
lint: $(V_DUT)
	@echo linting $(notdir $<)
	@$(VERILATOR) $(VERILATOR_FLAGS) --lint-only $<

.PHONY: vhier
vhier: $(V_DUT)
	@echo files required for $(notdir $<):
	@cd $(DLSC_ROOT) && vhier --input-files $(V_FLAGS) $<


#
# SystemPerl
#

ifdef USING_SYSTEMC

vpath %.sp $(SP_DIRS)
vpath %.cpp $(SC_DIRS)
vpath %.h $(SC_DIRS)

# create links to files not inside the object dir
# (since sp_preproc doesn't provide a good way of searching elsewhere)
.PHONY: systemperl
systemperl: $(SP_FILES) $(SC_FILES) $(SCH_FILES) | $(OBJDIR)
	@ln -s -f -t $(OBJDIR) $^

else

.PHONY: systemperl
systemperl:

endif


#
# Verilog (Icarus or ISim)
#

ifdef USING_VERILOG

# create links to files not inside the object dir
.PHONY: icarus
icarus: $(V_FILES) | $(OBJDIR)
	@ln -s -f -t $(OBJDIR) $^

else

.PHONY: icarus
icarus: 

endif


#
# Coverage merging
#

# merges results from all simulations run in this WORKROOT
COV_FILE_ALL := $(wildcard $(WORKROOT)/_*/*.cov)
$(WORKROOT)/coverage/merged_all.cov: $(COV_FILE_ALL)
	@[ -d $(@D) ] || mkdir -p $(@D)
	@$(VCOVERAGE) --noreport -write $@ $^

# remove _tbwrapper references
$(WORKROOT)/coverage/merged.cov: $(WORKROOT)/coverage/merged_all.cov
	@grep -v "_tbwrapper\.v" $^ > $@

.PHONY: coverage_all
coverage_all: $(WORKROOT)/coverage/merged.cov
	@$(VCOVERAGE) --all-files -o $(WORKROOT)/coverage $(V_FLAGS) $<


#
# Recurse to $(OBJDIR)
#

# create objdir
$(OBJDIR):
	@[ -d $@ ] || mkdir -p $@

# keep a record of parameters
vparams.txt:
	@echo '$(V_PARAMSI)' > $@

# invoke again in the objdir
.PHONY: recurse
recurse: gen verilator systemperl icarus vparams.txt $(OBJDIR)
	+@$(MAKE) --no-print-directory -C $(OBJDIR) -f $(THIS) CWD_TOP=$(CWD_TOP) $(MAKECMDGOALS)

# targets that can be passed through
.PHONY: build sim waves vcd gtkwave coverage
build sim waves vcd gtkwave coverage: recurse


# ^^^ ifneq (,$(filter _objdir%,$(notdir $(CURDIR))))
else
# *****************************************************************************
# in objdir now; have prereqs; can build remainder


ifdef USING_SYSTEMC

#
# Verilator
#

# just include results of previous verilator run
VM_CLASSES_FAST := 
VM_CLASSES_SLOW := 
VM_SUPPORT_FAST := 
VM_SUPPORT_SLOW := 
VM_GLOBAL_SLOW  := 
VM_GLOBAL_FAST  := 

include $(V_FILES_MK)

SP_FILES    += $(addsuffix .sp,$(VM_CLASSES_FAST) $(VM_CLASSES_SLOW))
C_FILES     += $(addsuffix .cpp,$(VM_SUPPORT_FAST) $(VM_SUPPORT_SLOW))
C_FILES     += $(addsuffix .cpp,$(VM_GLOBAL_FAST) $(VM_GLOBAL_SLOW))
    
C_DIRS      += $(VERILATOR_ROOT)/include
H_SYS_DIRS  += $(VERILATOR_ROOT)/include $(VERILATOR_ROOT)/include/vltstd

C_DEFINES   += VM_TRACE VM_COVERAGE WAVES=1 SP_COVERAGE_ENABLE
C_DEFINES   += VL_PRINTF=printf UTIL_PRINTF=sp_log_printf


#
# SystemPerl
#

# normally supplied by Verilator (but not if there are no Verilated modules in executable..)
C_FILES     += verilated.cpp Sp.cpp
    
SYSTEMPERL_INCLUDE ?= $(SYSTEMPERL)/src

H_SYS_DIRS  += $(SYSTEMPERL_INCLUDE)
C_DIRS      += $(SYSTEMPERL_INCLUDE)
    
C_DEFINES   += SYSTEMPERL

SP_FILES    := $(sort $(SP_FILES))

# all systemperl files should be in the current directory now
# (either generated there, or symlinked)
#vpath %.sp $(SP_DIRS)

SP_DEFINES  += $(DEFINES) $(C_DEFINES)
SP_DEFINES  := $(sort $(SP_DEFINES))

SP_FLAGS    += $(addprefix -D,$(SP_DEFINES))

.PHONY: systemperl
systemperl: $(SP_TESTBENCH)
	@echo preprocessing $(notdir $<)
	@$(SP_PREPROC) $(SP_FLAGS) --nolint --MMD $<.d --preproc $<

SP_FILES_CPP := $(SP_FILES:.sp=.cpp)
SP_FILES_H   := $(SP_FILES:.sp=.h)
SP_FILES_D   := $(SP_FILES:.sp=.sp.d)

# systemperl will build all of these files, but we only want make to run the
# command a single time.. have recipe be a no-op, but depend on the real command
$(SP_FILES_CPP) $(SP_FILES_H) : systemperl ; @:

# sp_preproc actually produces output files for the entire design hierarchy..
# so running it on each .sp file is redundant (and potentially dangerous)
#%.cpp %.h : %.sp
#	@echo preprocessing $(notdir $<)
#	@sp_preproc $(SP_FLAGS) --MMD $<.d --preproc $<

SC_FILES    += $(SP_FILES_CPP)
SCH_FILES   += $(SP_FILES_H)
D_FILES     += $(SP_FILES_D)


#
# SystemC
#

SC_FILES    := $(sort $(SC_FILES))
SCH_FILES   := $(sort $(SCH_FILES))
SC_DIRS     := $(sort $(SC_DIRS))

C_FILES     += $(SC_FILES)
C_DIRS      += $(SC_DIRS)
H_FILES     += $(SCH_FILES)
H_DIRS      += $(SC_DIRS)
H_SYS_DIRS  += $(SYSTEMC)/include
LDFLAGS     += -L$(SYSTEMC)/lib-$(SYSTEMC_ARCH)
LDLIBS      += -lsystemc
#LDLIBS      += -lscv


#
# C/C++
#

H_DIRS      += $(C_DIRS)

C_FILES     := $(sort $(C_FILES))
C_DIRS      := $(sort $(C_DIRS))
H_FILES     := $(sort $(H_FILES))
H_DIRS      := $(sort $(H_DIRS))
H_SYS_DIRS  := $(sort $(H_SYS_DIRS))

vpath %.h $(H_DIRS)
vpath %.cpp $(C_DIRS)

CPPFLAGS    += $(addprefix -I,$(H_DIRS))
CPPFLAGS    += $(addprefix -isystem,$(H_SYS_DIRS))

C_DEFINES   += $(DEFINES)
C_DEFINES   := $(sort $(C_DEFINES))
CPPFLAGS    += $(addprefix -D,$(C_DEFINES))

%.o : %.cpp | $(H_FILES)
	@echo compiling $(notdir $<)
	@$(CXX) $(CPPFLAGS) -MMD -o $@ -c $<

O_FILES     += $(C_FILES:.cpp=.o)
D_FILES     += $(C_FILES:.cpp=.d)


#
# Binary
#

O_FILES := $(sort $(O_FILES))
O_DIRS  := $(sort $(O_DIRS))

vpath %.o $(O_DIRS)

$(TESTBENCH).bin : $(O_FILES)
	@echo linking $(notdir $@)
	@$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@
	@strip $@
	@echo '$@ : $^' > $@.d

D_FILES += $(TESTBENCH).bin.d


#
# Execution
#

# run inside $(CWD) to allow executable to consistently reference data files
$(COV_FILE) $(LOG_FILE) : $(TESTBENCH).bin
	@cd $(CWD) && $(OBJDIR)/$< --log $(LOG_FILE) --cov $(COV_FILE)

# run simulation and generate VCD file.. but send it to a fifo and use vcd2lxt2
# to convert in real-time to an LXT2 file; from:
# http://www.veripool.org/boards/2/topics/show/150-Verilator-Converting-VCD-file-to-LXT-file-during-simulation
$(LXT_FILE) : $(TESTBENCH).bin
	@rm -f $@.vcd
	@mkfifo $@.vcd
	@vcd2lxt2 $@.vcd $@ &
	@cd $(CWD) && $(OBJDIR)/$< --log $(LOG_FILE) --cov $(COV_FILE) --vcd $@.vcd

$(VCD_FILE) : $(TESTBENCH).bin
	@cd $(CWD) && $(OBJDIR)/$< --log $(LOG_FILE) --cov $(COV_FILE) --vcd $@

.PHONY: build
build: $(TESTBENCH).bin

.PHONY: coverage
coverage: $(COV_FILE)
	@[ -d $(WORKDIR)/coverage ] || mkdir -p $(WORKDIR)/coverage
	@$(VCOVERAGE) --all-files -o $(WORKDIR)/coverage $(V_FLAGS) $<


# ^^^ ifdef USING_SYSTEMC
endif

ifdef USING_VERILOG
ifdef USING_ICARUS

#
# Icarus Verilog
#

ICARUS_FLAGS    += $(addprefix -D,$(V_DEFINES))
ICARUS_FLAGS    += $(addprefix -I,$(VH_DIRS))
ICARUS_FLAGS    += $(addprefix -y,$(V_DIRS))

# compile verilog
$(TESTBENCH).vvp : $(V_FILES)
	@echo compiling $@
	@iverilog -o $@ -M$@.d.pre -D DUMPFILE='"$(LXT_FILE)"' $(ICARUS_FLAGS) $(V_FILES)
	@echo -n "$@ : " > $@.d
	@cat $@.d.pre | sort | uniq | tr '\n' ' ' >> $@.d
	@rm -f $@.d.pre

D_FILES         += $(TESTBENCH).vvp.d

# generate just a log file
$(LOG_FILE) : $(TESTBENCH).vvp
	@IVERILOG_DUMPER=NONE vvp -l $(LOG_FILE) $<

# generate dump file and log
$(LXT_FILE) : $(TESTBENCH).vvp
	@vvp -l $(LOG_FILE) $< -lxt2

.PHONY: build
build: $(TESTBENCH).vvp

# TODO
coverage: sim


# ^^^ ifdef USING_ICARUS
endif


ifdef USING_ISIM

#
# Xilinx ISim
#

ISIM_FLAGS      += $(addprefix -d ,$(V_DEFINES))
ISIM_FLAGS      += $(addprefix -i ,$(VH_DIRS))
ISIM_FLAGS      += $(addprefix --sourcelibdir ,$(V_DIRS))
ISIM_FLAGS      += -d DUMPFILE='"$(VCD_FILE)"'

ISIM_FUSE_FLAGS += work.$(TESTBENCH)
ISIM_BIN_FLAGS  += -tclbatch $(DLSC_COMMON)/sim/dlsc_isim_cmd.tcl -log $(LOG_FILE)

# compile verilog
$(TESTBENCH).bin : $(V_FILES)
	@echo generating dependency list
	@vhier --input-files $(V_FLAGS) $(V_FILES) > $@.d.pre
	@echo -n "$@ : " > $@.d
	@cat $@.d.pre | sort | uniq | tr '\n' ' ' >> $@.d
	@rm -f $@.d.pre
	@echo compiling $@
	@vlogcomp $(ISIM_FLAGS) $(V_FILES)
	@echo fusing $@
	@fuse $(ISIM_FUSE_FLAGS) -o $@

D_FILES         += $(TESTBENCH).bin.d

# generate just a log file
$(LOG_FILE) : $(TESTBENCH).bin
	$(OBJDIR)/$< $(ISIM_BIN_FLAGS) -testplusarg NODUMP=1

# generate dump file (.vcd) and log
$(VCD_FILE) : $(TESTBENCH).bin
	@rm -f $(VCD_FILE)
	$(OBJDIR)/$< $(ISIM_BIN_FLAGS)

# TODO: ISim doesn't play nicely with the mkfifo and vcd2lxt2 technique
## generate dump file (.lxt) and log
#$(LXT_FILE) : $(TESTBENCH).bin
#	@rm -f $(VCD_FILE)
#	@mkfifo $(VCD_FILE)
#	@vcd2lxt2 $(VCD_FILE) $@ &
#	$(OBJDIR)/$< $(ISIM_BIN_FLAGS)

.PHONY: build
build: $(TESTBENCH).bin

# TODO
coverage: sim


# ^^^ ifdef USING_ISIM
endif
# ^^^ ifdef USING_VERILOG
endif


.PHONY: sim
sim: $(LOG_FILE)

.PHONY: vcd
vcd: $(VCD_FILE)

.PHONY: waves gtkwave

ifdef USING_ISIM
# ISim flow currently only supports VCD
waves: $(VCD_FILE)
gtkwave: $(VCD_FILE)
else
# Icarus natively supports LXT2, while Verilator supports LXT2
# by piping through vcd2lxt2
waves: $(LXT_FILE)
gtkwave: $(LXT_FILE)
endif

gtkwave:
	gtkwave $< &


# include dependency files
D_FILES := $(sort $(D_FILES))
-include $(D_FILES)


# ^^^ ifneq (,$(filter _objdir%,$(notdir $(CURDIR))))
endif

# ^^^ ifeq (,$(filter _%,$(notdir $(CURDIR))))
endif

