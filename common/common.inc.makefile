
VH_DIRS         += $(CWD)/sim $(CWD)/rtl
SP_DIRS         += $(CWD)/sim
SC_DIRS         += $(CWD)/sim
C_DIRS          += $(CWD)/sim
H_DIRS          += $(CWD)/sim

C_FILES         += dlsc_dpi.cpp

# dlsc_clog2.vh expects this
V_DEFINES       += USE_CLOG2

