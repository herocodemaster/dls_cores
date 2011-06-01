
.PHONY: default
default:
	@echo these aren\'t the makefiles you\'re looking for...

# most of the 'real' makefiles for running tests are located in places like:
# */tb/*_tb.makefile
#
# example invocation:
#   cd stereo/tb/
#   make -f dlsc_stereobm_prefiltered_tb.makefile -j8 sims
#

# remove all generated work directories
.PHONY: clean
clean:
	rm -rf */*/_work/

# remove everything except the .bin files
.PHONY: objclean
objclean:
	rm -f */*/_work/_*/_objdir/*.sp
	rm -f */*/_work/_*/_objdir/*.h
	rm -f */*/_work/_*/_objdir/*.cpp
	rm -f */*/_work/_*/_objdir/*.o
	rm -f */*/_work/_*/_objdir/*.d
	rm -f */*/_work/_*/_objdir/*.mk
	rm -f */*/_work/_*/_objdir/*.dat

