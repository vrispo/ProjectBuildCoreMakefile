DIR = ../$(S_DIR)

define search_file
$(eval found:="NO")
$(foreach E,$(1), $(if $(filter x$(E),x$(2)),$(eval found:="YES")))
endef

define do_ldd
$(eval L:=$(2))
$(eval FILES := $(shell readelf -d $(1) | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
$(foreach F, $(FILES),\
$(call search_file,$(L),$(shell "$(MCROSS)"$(CC) -print-file-name=$(F))) \
$(if $(filter $(found),"NO"),$(eval L:=$(L) $(shell "$(MCROSS)"$(CC) -print-file-name=$(F))) $(call do_ldd,$(shell "$(MCROSS)"$(CC) -print-file-name=$(F)),$(L)) ) \
)
endef

buildingroot: 
	@echo "	Building root"
	@echo CC is $(CC)
	cp -a $(DIR)/etc _install/etc
	cp $(DIR)/sbin/* _install/sbin
	rm -f _install/linuxrc
	rm -f _install/init
	ln -s /bin/busybox _install/init 

	mkdir -p _install/proc
	rm -f _install/lib && mkdir -p _install/lib
ifeq (x$(ARCH) , xmusl)
	@echo -n "	get musl in root... "
	cp -a $(MUSL)/$(MARCH)/lib/ld-musl-x86_64.so.1 _install/lib
	cp $(MUSL)/$(MARCH)/lib/libc.so _install/lib
else
	find _install  -maxdepth 0 -type f -delete -name lib64 && mkdir -p _install/lib64
	@echo "	get exec libs root $(GLIBC_LIB)"
#$(call get_exec_libs_root,_install/bin/busybox,_install,$(GLIBC_LIB))
	$(call do_ldd,_install/bin/busybox)
	@echo result of do_ldd is $(L)
	$(foreach K,$(L),$(eval res += $(shell basename $(K))))
	@echo result of foreach is $(res)
	$(eval LIBS := $(shell echo $(res) | grep -v vdso | grep -v ld-linux))
	@echo libs is $(LIBS)

#$(call do_ldd,_install/bin/busybox) il risultato è sempre in L che non è più stata modificata
	@echo result of do_ldd is $(L)
	$(eval res:="")
	$(foreach K,$(L),$(eval res += $(K)))
	@echo result of foreach is $(res)
	$(eval LD_LINUX += $(shell echo $(res) | grep ld-linux))
	@echo ld_linux is $(LD_LINUX)
ifeq (x$(GLIBC_LIB),x)
#$(eval D=$(shell $(call do_ldd2,$(1)) | grep libc.s | xargs dirname))
#the result of ldd2 is in res

	$(eval LIBDIR:=$(shell echo $(res) | grep libc.s | xargs dirname | xargs -n1 | sort -u | xargs))
	@echo res of find lib dir is $(LIBDIR)
	$(eval LDLINUXDIR := $(shell dirname $(LD_LINUX) | xargs -n1 | sort -u | xargs))
	@echo res of ld linux dir is $(LDLINUXDIR)
else
	$(eval LIBDIR := $(GLIBC_LIB))
	$(eval LDLINUXDIR := $(GLIBC_LIB))
endif
	$(foreach tLIBS,$(LIBS), \
	$(eval LIB:=$(shell find -H $(LIBDIR) -name $(tLIBS) | head -n 1)) \
	$(if $(filter $(LIB),''),echo Fetch Lib: $(tLIBS) not found in $(LIBDIR) - doing nothing,cp $(LIB) _install/lib/ ;) \
	)

	mkdir -p _install$(shell dirname $(LD_LINUX) | xargs -n1 | sort -u | xargs)
	$(foreach tLDLINUX,$(LD_LINUX), \
	$(eval LIB:=$(shell find -H $(LDLINUXDIR) -name  $(notdir $(tLDLINUX)) | head -n 1)) \
	$(if $(filter $(LIB),''),echo Fetch Lib: $(tLDLINUX) not found in $(LDLINUXDIR) - doing nothing,cp $(LIB) _install/lib ;) \
	)
	@echo "	done get_exec_libs_root"

	@echo call fetch std lib
ifeq (x$(GLIBC_LIB),x)
	@echo result of do_ldd is $(L)
	$(eval res:="")
	$(foreach K,$(L),$(eval res += $(K)))
	@echo result of foreach is $(res)
	$(eval LIBDIR:=$(shell echo $(res) | grep libc.s | xargs dirname | xargs -n1 | sort -u | xargs))
	@echo res of find lib dir is $(LIBDIR)	
else
	$(eval LIBDIR:=$(GLIBC_LIB))
endif

	$(eval LIB:=$(shell find -H $(LIBDIR) -name libpthread.so.0 | head -n 1)) 
	@echo LIB libpthread.so.0 is $(LIB)
	$(if $(filter $(LIB),''),echo Fetch Lib: libpthread.so.0 not found in $(LIBDIR) - doing nothing,cp $(LIB) _install/lib)


	$(eval LIB:=$(shell find -H $(LIBDIR) -name librt.so.1 | head -n 1))
	@echo LIB librt.so.1 is $(LIB)
	$(if $(filter $(LIB),''),echo Fetch Lib: librt.so.1 not found in $(LIBDIR) - doing nothing,cp $(LIB) _install/lib)

	$(eval LIB:=$(shell find -H $(LIBDIR) -name libdl.so.2 | head -n 1)) 
	@echo LIB libdl.so.2 is $(LIB)
	$(if $(filter $(LIB),''),echo Fetch Lib: libdl.so.2 not found in $(LIBDIR) - doing nothing,cp $(LIB) _install/lib)	

	$(eval LIBGCCDIR := $(shell "$(MCROSS)"$(CC) -print-libgcc-file-name))
	$(eval LIBGCCDIR := $(shell dirname $(LIBGCCDIR)))
	@echo LIBGCCDIR is $(LIBGCCDIR)
	$(eval r:=$(shell test -e $(LIBGCCDIR)/libgcc_s.so.1 && echo -n "yes"))
	@echo r is $(r)

	$(if $(filter $(r),yes), cp $(LIBGCCDIR)/libgcc_s.so.1 _install/lib/libgcc_s.so.1, cp $(LIBGCCDIR)/libgcc_s.so _install/lib/libgcc_s.so.1)
endif
	@echo end makefile building root