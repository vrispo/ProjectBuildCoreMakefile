define fetch_lib
	$(eval D=$(4))
	$(eval LIB=$(shell find -H $(D) -name $(2) | head -n 1))
ifneq (x$(LIB),x)
	cp $(LIB) $(3)/$(1)
else
	echo Fetch Lib: $(2) not found in $(D) - doing nothing
endif
endef

define find_lib_dir
	$(eval D=$(shell $(call do_ldd2,$(1)) | grep libc.s | xargs dirname))
	echo $(D)
endef

define search_file
	$(eval found="NO")
	$(foreach E,$(1), $(if $(filter x$(E),x$(2)),$(eval found="YES")))
	@echo $(found)
endef

define do_ldd
	$(eval L=$(2))
	$(eval FILES=$(shell readelf -d $(1) | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	@echo $(FILES)
endef

define do_ldd1
	$(eval LIBS=$(call do_ldd,$(1)))
	$(foreach K,$(LIBS),$(shell echo $(basename $(K))))
endef

define do_ldd2
	$(eval LIBS=$(call do_ldd,$(1)))
	$(foreach K,$(LIBS),$(shell echo $(K)))
endef

define get_exec_libs_root
	$(eval LIBS=$(shell $(call do_ldd1,$(1)) | grep -v vdso | grep -v ld-linux))
	$(eval LD_LINUX=$(shell $(call do_ldd2,$(1)) | grep ld-linux))
ifeq (x$(3),x)
	$(eval LIBDIR=$(call find_lib_dir,$(1)))
	$(eval LDLINUXDIR=$(shell dirname $$($(LD_LINUX))))
else
	$(eval LIBDIR=$(3))
	$(eval LDLINUXDIR=$(3))
endif

	$(foreach L,$(LIBS),$(call fetch_lib,lib,$(L),$(2),$(LIBDIR)))
	mkdir -p $(2)/$(shell dirname $$($(LD_LINUX)))
	$(call fetch_lib,/lib,$(basename $(LD_LINUX)),$(2),$(LDLINUXDIR)
endef

installsudo:
	@echo "	Installing sudo"
	cp $(shell pwd)/src/sudo $(BBBUILD)/_install/bin
	"$(MCROSS)"strip $(BBBUILD)/_install/bin/sudo
ifeq (x$(GLIBC_LIB),x)
	$(eval LIBDIR=$(call find_lib_dir,$(BBBUILD)/_install/bin/sudo))
else
	$(eval LIBDIR = $(GLIBC_LIB))
endif	
	@echo LIBDIR is $(LIBDIR)
ifneq (x$(ARCH),xmusl)
	@echo get_exec_libs_root bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo , bb_build-$(BBVER)$(EXTRANAME)/_install , $(LIBDIR)
	$(call get_exec_libs_root,$(BBBUILD)/_install/bin/sudo,$(BBBUILD)/_install,$(LIBDIR))
	@echo "	fetching libs... "
	$(eval LIB=$(shell find -H $(LIBDIR) -name libnss_compat.so.* | head -n 1))
ifneq (x$(LIB),x)
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib/
else
	@echo Fetch Lib: libnss_compat.so.* not found in $(LIBDIR)
endif
	$(eval LIB=$(shell find -H $(LIBDIR) -name libnss_files.so.* | head -n 1))
ifneq (x$(LIB),x)
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib/
else
	@echo Fetch Lib: libnss_files.so.* not found in $(LIBDIR)
endif
	@echo "done!"
endif