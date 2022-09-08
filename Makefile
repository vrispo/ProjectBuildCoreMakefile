BBVER = 1.29.3
GLIBCVER = 2.28
KVER = 4.28.16
SUDOVER = 1.8.26
SUDO_PATH = dist#sudover x.y.z se y = 8 sudo_path = dist else =dist/old
FILE_NAME ?= minimal_core
DIR_NAME = $(shell pwd)
S_DIR ?= ../Progetto
CONFIG_FILE = $(S_DIR)/Configs/config-busybox-2
CC = gcc

CPUS = $(shell grep processor /proc/cpuinfo | wc -l)

ifeq (x$(ARCH),xx86_64)
EXTRANAME = 64
CFLAGS = -m64
LDFLAGS = -m64
	ifneq ($(arch),x86_64)
CROSS ="--host=x86_64-unknown-linux-gnu"
	endif
endif

ifeq (x$(ARCH),xx86)
EXTRANAME = 32
CFLAGS = -m32
LDFLAGS = -m32
	ifneq ($(arch),x86_64)
CROSS = "--host=i686-unknown-linux-gnu"
	endif
endif

ifeq (x$(ARCH),xmusl)
EXTRANAME = musl
	ifeq ($(arch),x86_64)
CROSS ="--host=x86_64-unknown-linux-gnu"
MARCH ="x86_64-linux-musl"
	else
CROSS = "--host=i686-unknown-linux-gnu"
MARCH = "i686-linux-musl"
	endif
MCROSS =$(MUSL)/bin/$(MARCH)-
endif

#Adjust the cross-compilation variables if exists
ifneq (x$(PREFIX),x)
MCROSS =$(PREFIX)-
CROSS ="--host=$(PREFIX)"
ARCH =$(shell $(PREFIX)-gcc- -dumpmachine | cut -d '-' -f l)
endif

include $(S_DIR)/functions.mk

$(DIR_NAME)/$(FILE_NAME).gz: bb_build-$(BBVER)$(EXTRANAME)/_install/etc  bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo
ifneq ("$(wildcard bb_build-$(BBVER)$(EXTRANAME)/_install/lib64)","")
	@echo "	lib64 is there: copying it"
	$(eval FILES=$(shell ls bb_build-$(BBVER)$(EXTRANAME)/_install/lib64))
	$(foreach F,$(FILES),$(shell cp -a bb_build-$(BBVER)$(EXTRANAME)/_install/lib64/$(F) bb_build-$(BBVER)$(EXTRANAME)/_install/lib))
	rm -rf bb_build-$(BBVER)$(EXTRANAME)/_install/lib64; ln -s bb_build-$(BBVER)$(EXTRANAME)/_install/lib bb_build-$(BBVER)$(EXTRANAME)/_install/lib64
endif
	@echo -n "MkInitRAMFs bb_build-$(BBVER)$(EXTRANAME)/_install/etc $(DIR_NAME)/$(FILE_NAME)"
	cd bb_build-$(BBVER)$(EXTRANAME)/_install ; \
	find . | cpio -o -H newc | gzip > $(DIR_NAME)/$(FILE_NAME).gz

bb_build-$(BBVER)$(EXTRANAME)/_install/etc: bb_build-$(BBVER)$(EXTRANAME)/_install
	@echo "	Building root"
	cp -a $(S_DIR)/etc bb_build-$(BBVER)$(EXTRANAME)/_install/etc 
	cp $(S_DIR)/sbin/* bb_build-$(BBVER)$(EXTRANAME)/_install/sbin
	rm -f bb_build-$(BBVER)$(EXTRANAME)/_install/linuxrc
	rm -f bb_build-$(BBVER)$(EXTRANAME)/_install/init
	ln -s /bin/busybox bb_build-$(BBVER)$(EXTRANAME)/_install/init

	mkdir -p bb_build-$(BBVER)$(EXTRANAME)/_install/proc
	mkdir -p bb_build-$(BBVER)$(EXTRANAME)/_install/lib
ifeq (x$(ARCH),xmusl)
	@echo -n "	get musl in root... "
	cp -a $(MUSL)/$(MARCH)/lib/ld-musl-x86_64.so.l bb_build-$(BBVER)$(EXTRANAME)/_install/lib 
	cp $(MUSL)/$(MARCH)/lib/libc.so bb_build-$(BBVER)$(EXTRANAME)/_install/lib
else
	mkdir -p bb_build-$(BBVER)$(EXTRANAME)/_install/lib64
	@echo "	get exec libs root $(GLIBC_LIB)"

	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/busybox | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	@echo $(FILES)
	$(foreach F,$(FILES),\
	$(eval F=$(shell "$(MCROSS)"$(CC) -print-file-name=$(F))) \
	$(call search_file,"$(L)",$(shell "$(MCROSS)"$(CC) -print-file-name=$(F))) \
	$(if [$(found) = "NO"] , $(eval L="$(L) $(shell "$(MCROSS)"$(CC) -print-file-name=$(F))")  $(eval L1=$(call do_ldd,$(shell "$(MCROSS)"$(CC) -print-file-name=$(F)),"$(L)"))  $(eval L="$(L1)") )\
	)

	$(foreach K,$(L),$(eval tLIBS+= $(basename $(K))))
	$(eval LIBS=$(shell $(tLIBS) | grep -v vdso | grep -v ld-linux))
	@echo LIBS is $(LIBS)

	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/busybox | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))	
	@echo $(FILES)
	$(foreach F,$(FILES),\
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1="") ; $(eval L="$(L1)") fi ;\
	)

	$(foreach K,$(L),$(eval tLD_LINUXS+= $(K)))	
	$(eval LD_LINUX=$(shell $(tLD_LINUX) | grep ld-linux))
	@echo LD_LINUX is $(LD_LINUX)

ifeq (x$(GLIBC_LIB),x)
	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/busybox | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	$(foreach F,$(FILES),\
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1="") ; $(eval L="$(L1)") fi ;\
	)

	$(foreach K,$(L),$(eval tLIBDIR+= $(K)))	
	$(eval LIBDIR =$(shell $(tLIBDIR) | grep libc.s | xargs dirname))
	$(eval LDLINUXDIR=$(shell dirname $($(LD_LINUX))))
else
	$(eval LIBDIR=$(GLIBC_LIB)) 
	$(eval LDLINUXDIR=$(GLIBC_LIB))
endif
	@echo LIBDIR is $(LIBDIR)
	@echo LDLINUXDIR is $(LDLINUXDIR)
ifneq (x$(LIBS),x) 
	$(foreach K,$(LIBS), \
	$(eval DIR=lib); \
	$(call fetch_lib,$(DIR),$(K),bb_build-$(BBVER)$(EXTRANAME)/_install,$(LIBDIR)); \
	)
endif

	mkdir -p bb_build-$(BBVER)$(EXTRANAME)/_install/$(shell dirname $($(LD_LINUX)))
	$(eval LIB=$(shell find -H $(LDLINUXDIR) -name $(basename $(LD_LINUX)) | head -n 1))
ifneq ("x$(LIB)","x")
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib
else
	@echo Fetch Lib: $(basename $(LD_LINUX)) not found in $(LDLINUXDIR) - doing nothing
endif

	@echo "	Fetching standard libraries"
ifeq (x$(GLIBC_LIB),x)
	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/busybox | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	$(foreach F,$(FILES),\
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1="") ; $(eval L="$(L1)") fi ;\
	)

	$(foreach K,$(L),$(eval tLIBDIR+= $(K)))
	$(eval LIBDIR=$(shell $(tLIBDIR) | grep libc.s | xargs dirname))
else
	$(eval LIBDIR=$(GLIBC_LIB))
endif
	@echo LIBDIR is $(LIBDIR)
	$(eval LIB=$(shell find -H $(LIBDIR) -name libpthread.so.0 | head -n 1))
ifneq ("x$(LIB)","x")
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib/
else
	@echo Fetch Lib: libpthread.so.0 not found in $(LIBDIR) - doing nothing
endif
	$(eval LIB=$(shell find -H $(LIBDIR) -name librt.so.1 | head -n 1))
ifneq ("x$(LIB)","x")
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib/
else
	@echo Fetch Lib: librt.so.1 not found in $(LIBDIR) - doing nothing
endif
	$(eval LIB=$(shell find -H $(LIBDIR) -name libdl.so.2 | head -n 1))
ifneq ("x$(LIB)","x")
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib/
else
	@echo Fetch Lib: libdl.so.2 not found in $(LIBDIR) - doing nothing
endif
	$(eval LIBGCCDIR=$(shell dirname $$("$(MCROSS)"$(CC) -print-libgcc-file-name)))
	@echo LIBGCCDIR is $(LIBGCCDIR)
ifneq ("$(wildcard $(LIBGCCDIR)/libgcc_s.so.1)","")
	cp $(LIBGCCDIR)/libgcc_s.so.1 bb_build-$(BBVER)$(EXTRANAME)/_install/lib/libgcc_s.so.1
else
	cp $(LIBGCCDIR)/libgcc_s.so bb_build-$(BBVER)$(EXTRANAME)/_install/lib/libgcc_s.so.1	
endif
endif
	@echo "	done!"

bb_build-$(BBVER)$(EXTRANAME)/_install: bb_build-$(BBVER)$(EXTRANAME)
	@echo "	Installing BusyBox"
	rm -rf bb_build-$(BBVER)$(EXTRANAME)/_install
	cd $(BUILDDIR) ;\
	make install V=1     CC="$(MCROSS)$(CC)" CROSS_COMPILE=$(MCROSS)                     > install_bb.log 2> install_bb.err
	@echo "	done!"

bb_build-$(BBVER)$(EXTRANAME): busybox-$(BBVER) #init_config
	@echo "	Building BusyBox"
	$(eval BUILDDIR := bb_build-$(BBVER)$(EXTRANAME))
	mkdir -p $(BUILDDIR)
	@echo -n "	configuring... "
	cd $(BUILDDIR) ;\
	cp ../$(CONFIG_FILE) .config;\
	make -C $(shell pwd)/busybox-$(BBVER) CC="$(MCROSS)$(CC)" CROSS_COMPILE=$(MCROSS) O=$(shell pwd)/$(BUILDDIR) oldconfig  > config_bb.log 2> config_bb.err 
	@echo "done!"
	@echo -n "	compiling..."
ifneq ($(CPUS),1) 
	$(eval CPUS = $(shell expr $(CPUS) - 1))
endif 	
	cd $(BUILDDIR) ;\
	make -j $(CPUS) V=1       CC="$(MCROSS)$(CC)" CROSS_COMPILE=$(MCROSS)                     > build_bb.log  2> build_bb.err
	@echo "	done!"

busybox-$(BBVER): busybox-$(BBVER).tar.bz2
	@echo "	uncompressing busybox-$(BBVER).tar.bz2"
	tar xjf busybox-$(BBVER).tar.bz2
	@echo "	done!"
ifneq ("$(wildcard $(S_DIR)/Patches/BusyBox/$(BBVER))","")	
	@echo "	PATCHES exists"
endif

busybox-$(BBVER).tar.bz2:
	@echo "	Getting BusyBox"
ifneq ("$(wildcard busybox-$(BBVER).tar.bz2)","")
	@echo "busybox-$(BBVER).tar.bz2 already exists"
else
	@echo "downloading busybox-$(BBVER).tar.bz2"
	wget http://www.busybox.net/downloads//busybox-$(BBVER).tar.bz2
	@echo "	done!"
endif	

bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo: sudo_build-$(SUDOVER)$(EXTRANAME) bb_build-$(BBVER)$(EXTRANAME)/_install/etc
	@echo "	Installing sudo"
	cp sudo_build-$(SUDOVER)$(EXTRANAME)/src/sudo bb_build-$(BBVER)$(EXTRANAME)/_install/bin
	"$(MCROSS)"strip bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo
ifeq (x$(GLIBC_LIB),x)
	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
ifneq (x$(FILES),x)
	for F in $(FILES) ; do \
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1=$(call do_ldd,$(F),"$(L)")) ; $(eval L="$(L1)") fi ;\
	done;
endif
ifneq (x$(L),x)	
	$(foreach K,$(L),$(eval tLIBDIR+= $(K)))
endif
	$(eval LIBDIR = $(shell $(tLIBDIR) | grep libc.s | xargs dirname))
else
	$(eval LIBDIR = $(GLIBC_LIB))
endif	
	@echo LIBDIR is $(LIBDIR)
ifneq (x$(ARCH),xmusl)
	@echo get_exec_libs_root bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo , bb_build-$(BBVER)$(EXTRANAME)/_install , $(LIBDIR)
	
	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	$(foreach F,$(FILES),\
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1="") ; $(eval L="$(L1)") fi ;\
	)

	$(foreach K,$(L),$(eval tLIBS+= $(basename $(K))))
	$(eval LIBS=$(shell $(tLIBS) | grep -v vdso | grep -v ld-linux))
	@echo LIBS is $(LIBS)

	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	$(foreach F,$(FILES),\
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1="") ; $(eval L="$(L1)") fi ;\
	)

	$(foreach K,$(L),$(eval tLD_LINUX+= $(K)))
	$(eval LD_LINUX=$(shell $(tLD_LINUX) | grep ld-linux))
	@echo LD_LINUX is $(LD_LINUX)

ifeq (x$(LIBDIR),x)
	$(eval FILES=$(shell readelf -d bb_build-$(BBVER)$(EXTRANAME)/_install/bin/sudo | grep "Libreria condivisa" | cut -d '[' -f 2 | cut -d ']' -f 1))
	$(foreach F,$(FILES),\
	$(eval F=$("$(MCROSS)"$(CC) -print-file-name=$(F))); \
	$(call search_file,"$(L)",$(F)); \
	if [$(found) = "NO"] then $(eval L="$(L) $(F)") ; $(eval L1="") ; $(eval L="$(L1)") fi ;\
	)

	$(foreach K,$(L),$(eval tLIBDIR+= $(K)))
	$(eval LIBDIR =$(shell $(tLIBDIR) | grep libc.s | xargs dirname))

	$(eval LDLINUXDIR=$(shell dirname $$($(LD_LINUX))))
else
	$(eval LIBDIR=$(LIBDIR)) 
	$(eval LDLINUXDIR=$(LIBDIR))
endif
	@echo LIBDIR is $(LIBDIR)
	@echo LDLINUXDIR is $(LDLINUXDIR)

	$(foreach K,$(LIBS), \
	$(eval DIR=lib); \
	$(call fetch_lib,$(DIR),$(K),bb_build-$(BBVER)$(EXTRANAME)/_install,$(LIBDIR)); \
	)

	mkdir -p bb_build-$(BBVER)$(EXTRANAME)/_install/$(shell dirname $$($(LD_LINUX)))
	$(eval LIB=$(shell find -H $(LDLINUXDIR) -name $(basename $(LD_LINUX)) | head -n 1))
ifneq ("x$(LIB)","x")
	cp $(LIB) bb_build-$(BBVER)$(EXTRANAME)/_install/lib
else
	@echo Fetch Lib: $(basename $(LD_LINUX)) not found in $(LDLINUXDIR) - doing nothing
endif

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

sudo_build-$(SUDOVER)$(EXTRANAME): sudo-$(SUDOVER) #init_config
	@echo Building sudo
	$(eval BUILDDIRSUDO := sudo_build-$(SUDOVER)$(EXTRANAME))
	mkdir -p $(BUILDDIRSUDO)
	@echo -n "	configuring... "
	cd $(BUILDDIRSUDO) ; \
	CC=$(MCROSS)"$(CC)" ../sudo-$(SUDOVER)/configure --prefix=/ --disable-authentication --disable-shadow --disable-pam-session --disable-zlib --without-lecture --without-sendmail --without-umask --without-interfaces --without-pam --enable-static --disable-shared --enable-static-sudoers $(CROSS) > config_sudo.log 2> config_sudo.err
	@echo "done!"
	@echo -n "    compiling... "
	cd $(BUILDDIRSUDO) ; \
	make -j $(CPUS) CC=$(MCROSS)"$(CC)"                 > build_sudo.log 2> build_sudo.err
	@echo "done!"

sudo-$(SUDOVER): sudo-$(SUDOVER).tar.gz
	@echo "	uncompressing sudo-$(SUDOVER).tar.gz"
	tar xzf sudo-$(SUDOVER).tar.gz

sudo-$(SUDOVER).tar.gz:
	@echo Getting sudo
	@echo "	downloading sudo-$(SUDOVER).tar.gz "
	wget http://www.sudo.ws/$(SUDO_PATH)/sudo-$(SUDOVER).tar.gz

#init_config:
#Build glibc eventually with kernel headers if requested
#ifeq (x$(BUILD_GLIBC),xYesPlease)
#	@echo "Build GLIBC eventually with kernel headers"
#	$(eval GLIBC_SYSROOT =$(shell pwd)/glibc-sysroot)
#	$(eval GLIBC_LIB =GLIBC_SYSROOT/lib)
#	ifeq (x$(KERNEL_HEADERS),xYesPlease)
#	@echo get Kernel Headers
#	ifneq ("$(wildcard linux-$(KVER))","")
#	@echo linux-$(KVER) already exists
#	else
#	ifneq ("$(wildcard linux-$(KVER).tar.xz)","")
#	@echo linux-$(KVER).tar.gz already exists
#	else
#	$(eval MAJ=$(shell echo $(KVER) | cut -d '.' -f 1)) 
#	$(eval MIN=$(shell echo $(KVER) | cut -d '.' -f 2))
#	$(eval KPATH=v$(MAJ).x)
#	ifeq ($(MAJ),2)
#	$(eval KPATH=v$(MAJ).$(MIN))
#	endif
#	ifeq ($(MAJ),3)
#		ifeq ($(MIN),0)
#	$(eval KPATH=v3.0)
#		endif
#	endif
#	@echo "	downloading Kernel Headers"
#	wget http://www.kernel.org/pub/linux/kernel/$(KPATH)/linux-$(KVER).tar.xz
#	endif
#	@echo "	uncompressing Kernel Headers"	
#	tar xvf linux-$(KVER).tar.xz	
#	endif
#	@echo "	install Kernel Headers"
#	mkdir -p KHBuild
#	$(eval CROSS_COMPILE=$(MCROSS))
#	cd KHBuild ;\
#	make -C ../linux-$(KVER) O=$(shell pwd) defconfig ;\
#	make INSTALL_HDR_PATH=$(GLIBC_SYSROOT) headers_install
#	$(eval CC =$(CC) -L$(shell pwd)/glibc-sysroot/lib --sysroot==$(shell pwd)/glibc-sysroot -i system $(shell pwd)/glibc--sysroot/include)
#	endif
#	@echo "Getting GNU Libc"
#	ifneq ("$(wildcard glibc-$(GLIBCVER))","")
#	@echo glibc-$(GLIBCVER) already exists
#	else
#		ifneq ("$(wildcard glibc-$(GLIBCVER).tar.xz)","")
#	@echo glibc-$(GLIBCVER).tar.xz already exists
#		else
#	@echo "	downloading $(GLIBCVER).tar.xz"
#	wget http://ftp.gnu.org/gnu/glibc/$(GLIBCVER).tar.xz
#		endif
#	@echo "	uncompressing $(GLIBCVER).tar.xz"
#	tar xf $(GLIBCVER).tar.xz
#	endif	
#	@echo "	Building GNU Libc"
#	mkdir -p  glibc_build-$(GLIBCVER)$(EXTRANAME)
#	@echo -n "		configuring... "
#	cd glibc_build-$(GLIBCVER)$(EXTRANAME) ; \
#	CC="$(MCROSS)$(CC)" ../glibc-$(GLIBCVER)/configure --prefix=/ $(CROSS) > config_glibc.log 2> config_glibc.err
#	@echo "done!"
#	@echo -n "		compiling... "
#	cd glibc_build-$(GLIBCVER)$(EXTRANAME) ; \
#	CC="$(MCROSS)$(CC)" make -j $(CPUS) > build_glibc.log 2> build_glibc.err
#	@echo "	done!"
#	@echo "	Installing GNU Libc"
#	cd glibc_build-$(GLIBCVER)$(EXTRANAME) ; \
#	DESTDIR=$(GLIBC_SYSROOT) CC="$(MCROSS)$(CC)" make install INSTALL_PROGRAM="install -s --strip-program=$(MCROSS)'strip'" > install_glibc.log 2> install_glibc.err
#endif

clean:
	rm -f -r $(DIR_NAME)/*