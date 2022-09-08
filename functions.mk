found="NO"

define search_file
	$(eval found="NO")
	$(foreach E,$(1), $(if [x$(E) = x$(2)],$(eval found="YES")))
	@echo $(found)
endef

define do_ldd
	$(eval L=$(2))
	$(eval FILES=$(shell readelf -d $(1) | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	$(foreach F,$(FILES),\
	$(eval F=$(shell "$(MCROSS)"$(CC) -print-file-name=$(F))) \
	$(call search_file,"$(L)",$(shell "$(MCROSS)"$(CC) -print-file-name=$(F))) \
	$(if [$(found) = "NO"] , $(eval L="$(L) $(shell "$(MCROSS)"$(CC) -print-file-name=$(F))")  $(eval L1=$(call do_ldd,$(shell "$(MCROSS)"$(CC) -print-file-name=$(F)),"$(L)")) $(eval L="$(L1)") ) \
	)
	echo $(L)
endef

define do_ldd1
	$(eval LIBS=$(call do_ldd,$(1)))
	$(foreach K,$(LIBS),$(eval tLIBS+= $(basename $(K))))
endef

define do_ldd2
	$(eval LIBS=$(call do_ldd,$(1)))
	$(foreach K,$(LIBS),$(eval tLIBS+= $(shell echo $(K))))
endef

define find_lib_dir
	$(eval D=$(shell $(call do_ldd2,$(1)) | grep libc.s | xargs dirname))
	echo $(D)
endef

define fetch_lib
	$(eval D=$(4))
	$(eval LIB=$(shell find -H $(D) -name $(2) | head -n 1))
	$(if ["x$(LIB)" != "x"],$(shell cp $(LIB) $(3)/$(1)),$(shell echo Fetch Lib: $(2) not found in $(D) - doing nothing))
endef

define get_exec_libs_root
	$(eval LIBS=$(shell $(call do_ldd1,$(1)) | grep -v vdso | grep -v ld-linux))
	$(eval LD_LINUX=$(shell $(call do_ldd2,$(1)) | grep ld-linux))
	if [x$(3) = x] ; then \
	$(eval LIBDIR=$(call find_lib_dir,$(1))) ; \
	$(eval LDLINUXDIR=$(shell dirname $(LD_LINUX))) ; \
	else
	$(eval LIBDIR=$(3)) ; \
	$(eval LDLINUXDIR=$(3)) ;\
	fi
	
	for K in $(LIBS) ; do \
	$(eval DIR=lib); \
	$(call fetch_lib,$(DIR),$K,$(2),$(LIBDIR)); \
	done;

	$(shell mkdir -p $(2)/$(shell dirname $(LD_LINUX)))
	$(call fetch_lib,/lib,$(basename $(LD_LINUX)),$(2),$(LDLINUXDIR))
endef