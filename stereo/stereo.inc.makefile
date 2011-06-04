
DLSC_DEPENDS    += alu mem rvh sync
V_DIRS          += $(CWD)/rtl

# executable model
DLSC_STEREOBM_MODEL := $(CWD)/sim/_gen/dlsc_stereobm_model.bin

gen: $(DLSC_STEREOBM_MODEL)

$(DLSC_STEREOBM_MODEL) : $(CWD)/sim/dlsc_stereobm_models_program.cpp $(CWD)/tb/dlsc_stereobm_models.cpp
	@echo building $(notdir $@)
	@[ -d $(@D) ] || mkdir -p $(@D)
	@$(CXX) -O2 -o $@ -I/usr/include/opencv -I$(CWD)/tb $^ -lcv -lcvaux -lhighgui -lboost_program_options

