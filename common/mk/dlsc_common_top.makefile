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

# don't use default rules
.SUFFIXES:

# don't remove intermediate files
.SECONDARY: 

# by default, run a single simulation with code coverage
.PHONY: default
default: coverage

# multiple sims targets for parallel execution
.PHONY: sims sims0 sims1 sims2 sims3
sims: sims0 sims1 sims2 sims3
sims0:
sims1:
sims2:
sims3:


#
# Utilities
#

dlsc-dir    = $(patsubst %/,%,$(dir $(1)))
dlsc-base   = $(basename $(notdir $(1)))
dlsc-md5sum = $(firstword $(shell echo "$(1)" | md5sum))


#
# Common paths
#

DLSC_ROOT   := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
DLSC_ROOT   := $(DLSC_ROOT)/../../common
DLSC_ROOT   := $(call dlsc-dir,$(realpath $(DLSC_ROOT)))

DLSC_COMMON := $(DLSC_ROOT)/common

DLSC_MAKEFILE_BOT := $(DLSC_COMMON)/mk/dlsc_common_bot.makefile

CWD_TOP     := $(CURDIR)
CWD         := $(CWD_TOP)

THIS        := $(realpath $(firstword $(MAKEFILE_LIST)))


#
# External tools
#

ifndef VERILATOR_ROOT
$(error VERILATOR_ROOT must be set)
endif
ifndef SYSTEMPERL
$(error SYSTEMPERL must be set)
endif
ifndef SYSTEMC
$(error SYSTEMC must be set)
endif
ifndef SYSTEMC_ARCH
$(error SYSTEMC_ARCH must be set)
endif

VERILATOR   := $(VERILATOR_ROOT)/bin/verilator
SP_PREPROC  := $(SYSTEMPERL)/sp_preproc
VCOVERAGE   := $(SYSTEMPERL)/vcoverage

TBWRAPPER   := $(DLSC_COMMON)/tools/dlsc_tbwrapper.pl


#
# Variables
#

DLSC_DEPENDS    := common

DEFINES         := DLSC_DEBUG_WARN DLSC_DEBUG_INFO
DEFINES         += SIMULATION DLSC_SIMULATION

# Testbench
V_PARAMS        :=
V_PARAMS_DEF    := 
V_DUT           :=
# one or the other; not both!
SP_TESTBENCH    := 
V_TESTBENCH     :=

# Verilog
V_DEFINES       := 
V_FILES         := 
V_DIRS          := $(CWD)
VH_DIRS         := $(CWD)
V_FLAGS         := +libext+.v+.vh
# pre-3.810 Verilator doesn't support these extra warning options
# UNUSED warning seems to trigger on Verilator-generated coverage code.. can't really use it yet
VERILATOR_FLAGS := -Wall -Wwarn-style -Wno-UNUSED
ICARUS_FLAGS    := 

# SystemPerl
SP_DEFINES      := 
SP_FILES        :=
SP_DIRS         := $(CWD)
SP_FLAGS        := 

# SystemC
SC_FILES        := 
SCH_FILES       := 
SC_DIRS         := $(CWD)

# C/C++
C_DEFINES       := 
C_FILES         :=
C_DIRS          := $(CWD)
H_FILES         :=
H_DIRS          := $(CWD)
H_SYS_DIRS      := 
O_FILES         := 
O_DIRS          := 
CPPFLAGS        := -O1 -Wall -Wno-uninitialized
LDFLAGS         := -Wall
LDLIBS          := -lm -lstdc++

# Dependencies
D_FILES         := 

