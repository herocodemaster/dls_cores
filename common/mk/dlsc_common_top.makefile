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
sims:
sims0:
sims1:
sims2:
sims3:

.PHONY: gen
gen: 


#
# Utilities
#

SHELL       := /bin/bash

dlsc-dir    = $(patsubst %/,%,$(dir $(1)))
dlsc-base   = $(basename $(notdir $(1)))
dlsc-md5sum = $(firstword $(shell echo "$(1)" | md5sum))


#
# Common paths
#

DLSC_ROOT   := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
DLSC_ROOT   := $(DLSC_ROOT)/../../common
DLSC_ROOT   := $(call dlsc-dir,$(realpath $(DLSC_ROOT)))

# set a default path to look for includes on
DLSC_PATH   ?= $(DLSC_ROOT)

DLSC_COMMON := $(DLSC_ROOT)/common

DLSC_MAKEFILE_BOT := $(DLSC_COMMON)/mk/dlsc_common_bot.makefile

CWD_TOP     := $(CURDIR)
CWD         := $(CWD_TOP)

THIS        := $(realpath $(firstword $(MAKEFILE_LIST)))


#
# Simulation targets
#

DLSC_SIM_TARGETS := sims0 sims1 sims2 sims3

define DLSC_SIM_TEMPLATE
DLSC_SIM_TARGET_NAME := dsim__$$(call dlsc-md5sum,foo_$(1))
DLSC_SIM_TARGETS += $$(DLSC_SIM_TARGET_NAME)
$$(DLSC_SIM_TARGET_NAME):
	$$(MAKE) -f $$(THIS) V_PARAMS=$(1)
endef

dlsc-sim    = $(eval $(call DLSC_SIM_TEMPLATE,$(1)))



#
# Variables
#

DLSC_DEPENDS    := common

DEFINES         := DLSC_DEBUG_WARN=1 DLSC_DEBUG_INFO=1
ifneq "$(MAKECMDGOALS)" "vhier"
    # only want to include simulations files when not printing hierarchy
    DEFINES         += SIMULATION=1 DLSC_SIMULATION=1
endif

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
# PINCONNECTEMPTY fires on explicit empty connections (very common)
VERILATOR_FLAGS := -Wall -Wwarn-style -Wno-UNUSED -Wno-PINCONNECTEMPTY
ICARUS_FLAGS    := -Wall -Wno-timescale
ISIM_FLAGS      := --incremental
ISIM_FUSE_FLAGS := --incremental
ISIM_FUSE_LIBS  :=
ISIM_BIN_FLAGS  :=

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
CPPFLAGS        := -O2 -Wall -Wno-uninitialized -fpermissive
LDFLAGS         := -Wall
LDLIBS          := -lm -lstdc++

# Dependencies
D_FILES         :=

