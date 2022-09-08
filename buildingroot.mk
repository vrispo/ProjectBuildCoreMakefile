DIR = ../../Progetto

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

buildingroot:
	@echo "	Building root"
	cp -a $(DIR)/etc _install/etc
	cp $(DIR)/sbin/* _install/sbin
	rm -f _install/init
	ln -s /bin/busybox _install/init 

	mkdir -p _install/proc

	mkdir -p _install/lib 
ifeq (x$(ARCH) , xmusl)
	echo -n "	get musl in root... "
	cp -a $(MUSL)/$(MARCH)/lib/ld-musl-x86_64.so.1 _install/lib
	cp $(MUSL)/$(MARCH)/lib/libc.so _install/lib
else
	mkdir -p _install/lib64
	echo -n "	get exec libs root $(GLIBC_LIB)"
	$(call get_exec_libs_root,_install/bin/busybox,_install,$(GLIBC_LIB))
endif
