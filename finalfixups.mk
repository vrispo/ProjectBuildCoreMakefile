DIR := ../../$(S_DIR)

all:
ifneq ("$(wildcard lib64)","")
	@echo "	lib64 is there: copying it"
	$(eval FILES=$(shell ls lib64))
	$(foreach F,$(FILES),$(shell cp -a lib64/$(F) lib))
	rm -rf lib64 
	ln -s lib lib64
endif