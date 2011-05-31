
include $(DLSC_MAKEFILE_TOP)

V_DUT           += dlsc_stereobm_buffered.v

# a bit of a hack..
V_PARAMS_DEF    += \
    IS_BUFFERED=1

# rest of the makefile..
include $(CWD)/dlsc_stereobm_tb.inc.makefile

