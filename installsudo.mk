DIR = ../../Progetto

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

installsudo:
	@echo "	Installing sudo"
	cp src/sudo $(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/bin
	$(shell "$(MCROSS)"strip $(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo)

ifeq (x$(GLIBC_LIB),x)
	$(call do_ldd,$(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo)
	@echo result of do_ldd is $(L)
	$(eval res:="")
	$(foreach K,$(L),$(eval res += $(K)))
	@echo result of foreach is $(res)
	$(eval LIBDIR:=$(shell echo $(res) | grep libc.s | xargs dirname | xargs -n1 | sort -u | xargs))
	@echo res of find lib dir is $(LIBDIR)
else
	$(eval LIBDIR:=$(GLIBC_LIB))
endif

ifneq (x$(ARCH),xmusl)
	@echo "	get exec libs root $(GLIBC_LIB)"
#$(call get_exec_libs_root,$(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo,$(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install,$(LIBDIR))
	$(call do_ldd,$(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo)
	@echo result of do_ldd is $(L)
	$(eval res:="")
	$(foreach K,$(L),$(eval res += $(shell basename $(K))))
	@echo result of foreach is $(res)
	$(foreach K,$(res), $(eval LIBS += $(shell echo $(K) | grep -v vdso | grep -v ld-linux)))
	@echo libs is $(LIBS)

#$(call do_ldd,_install/bin/busybox) il risultato è sempre in L che non è più stata modificata
	@echo result of do_ldd is $(L)
	$(eval res:="")
	$(foreach K,$(L),$(eval res += $(K)))
	@echo result of foreach is $(res)
	$(foreach K,$(res), $(eval LD_LINUX += $(shell echo $(K) | grep ld-linux)))
	@echo ld_linux is $(LD_LINUX)
ifeq (x$(LIBDIR),x)
#$(eval D=$(shell $(call do_ldd2,$(1)) | grep libc.s | xargs dirname))
#the result of ldd2 is in res

	$(eval LIBDIR:=$(shell echo $(res) | grep libc.s | xargs dirname | xargs -n1 | sort -u | xargs))
	@echo res of find lib dir is $(LIBDIR)
	$(eval LDLINUXDIR := $(shell dirname $(LD_LINUX) | xargs -n1 | sort -u | xargs))
	@echo res of ld linux dir is $(LDLINUXDIR)
else
	$(eval LIBDIR := $(LIBDIR))
	$(eval LDLINUXDIR := $(LIBDIR))
endif
	$(foreach tLIBS,$(LIBS), \
	$(eval DIRfetch := lib) \
	$(eval LIB:=$(shell find -H $(LIBDIR) -name $(tLIBS) | head -n 1)) \
	$(if $(filter x$(LIB),x),$(shell echo Fetch Lib: $(tLIBS) not found in $(LIBDIR) - doing nothing),$(shell cp $(LIB) $(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/$(DIRfetch))) \
	)

	mkdir -p _install$(shell dirname $(LD_LINUX) | xargs -n1 | sort -u | xargs)
	$(foreach tLDLINUX,$(LD_LINUX), \
	$(eval LIB:=$(shell find -H $(LDLINUXDIR) -name  $(notdir $(tLDLINUX)) | head -n 1)) \
	$(if $(filter "x$(LIB),x"),$(shell echo Fetch Lib: $(tLDLINUX) not found in $(LDLINUXDIR) - doing nothing),$(shell cp $(LIB) $(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/$(LDLINUXDIR))) \
	)
	@echo "	done get_exec_libs_root"
	@echo "	fetching libs... "

	$(eval LIB:=$(shell find -H $(LIBDIR) -name libnss_compat.so.* | head -n 1)) 
	$(if $(filter x$(LIB),x),$(shell echo Fetch Lib: libnss_compat.so.* not found in $(LIBDIR) - doing nothing),$(shell cp $(LIB) $(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/lib/)) 

	$(eval LIB:=$(shell find -H $(LIBDIR) -name libnss_files.so.* | head -n 1)) 
	$(if $(filter x$(LIB),x),$(shell echo Fetch Lib: libnss_files.so.* not found in $(LIBDIR) - doing nothing),$(shell cp $(LIB) $(DIR_NAME)/bb_build-$(BBVER)$(EXTRANAME)/_install/lib/)) 
endif