
C_DIRS          += $(CWD)/sim
H_DIRS          += $(CWD)/sim

C_FILES         += dlsc_tlm_mm.cpp
C_FILES         += dlsc_tlm_utils.cpp

# needed for TLM
C_DEFINES       += SC_INCLUDE_DYNAMIC_PROCESSES

