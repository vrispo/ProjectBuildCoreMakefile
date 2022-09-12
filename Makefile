BBVER := 1.29.3
GLIBCVER := 2.28
KVER := 4.28.16
SUDOVER := 1.8.26
SUDO_PATH := dist#sudover x.y.z se y = 8 sudo_path = dist else =dist/old
FILE_NAME ?= minimal_core
DIR_NAME := $(shell pwd)
S_DIR ?= ../Progetto
CC := gcc

CPUS := $(shell grep processor /proc/cpuinfo | wc -l)
ifneq ($(CPUS),1) 
CPUS := $(shell expr $(CPUS) - 1)
endif

ifeq (x$(ARCH),xx86_64)
EXTRANAME := 64
CFLAGS := -m64
LDFLAGS := -m64
	ifneq ($(arch),x86_64)
CROSS :="--host=x86_64-unknown-linux-gnu"
	endif
endif

ifeq (x$(ARCH),xx86)
EXTRANAME := 32
CFLAGS := -m32
LDFLAGS := -m32
	ifneq ($(arch),x86_64)
CROSS := "--host=i686-unknown-linux-gnu"
	endif
endif

ifeq (x$(ARCH),xmusl)
EXTRANAME := musl
	ifeq ($(arch),x86_64)
CROSS :="--host=x86_64-unknown-linux-gnu"
MARCH :="x86_64-linux-musl"
	else
CROSS := "--host=i686-unknown-linux-gnu"
MARCH := "i686-linux-musl"
	endif
MCROSS :=$(MUSL)/bin/$(MARCH)-
endif

#Adjust the cross-compilation variables if exists
ifneq (x$(PREFIX),x)
MCROSS :=$(PREFIX)-
CROSS :="--host=$(PREFIX)"
ARCH :=$(shell $(PREFIX)-gcc- -dumpmachine | cut -d '-' -f l)
endif

export CC , EXTRANAME , DIR_NAME , MCROSS , SUDOVER , BBVER , CPUS , S_DIR

$(DIR_NAME)/$(FILE_NAME).gz: bb_build-$(BBVER)$(EXTRANAME)/_install/lib/libnss_*
	cd bb_build-$(BBVER)$(EXTRANAME)/_install && $(MAKE) -f ../../$(S_DIR)/finalfixups.mk
	@echo "	done final fixups!"
	@echo -n "MkInitRAMFs bb_build-$(BBVER)$(EXTRANAME)/_install $(DIR_NAME)/$(FILE_NAME)"
	cd bb_build-$(BBVER)$(EXTRANAME)/_install ; \
	find . | cpio -o -H newc | gzip > $(DIR_NAME)/$(FILE_NAME).gz

bb_build-$(BBVER)$(EXTRANAME)/_install/lib/libnss_*:bb_build-$(BBVER)$(EXTRANAME)/_install/lib sudo_build-$(SUDOVER)$(EXTRANAME)
	cd sudo_build-$(SUDOVER)$(EXTRANAME) && $(MAKE) -f ../$(S_DIR)/installsudo.mk 
	@echo "	done!"

bb_build-$(BBVER)$(EXTRANAME)/_install/lib: bb_build-$(BBVER)$(EXTRANAME)/_install
	cd bb_build-$(BBVER)$(EXTRANAME) && $(MAKE) -f ../$(S_DIR)/buildingroot.mk
	@echo "	done buildingroot!"

bb_build-$(BBVER)$(EXTRANAME)/_install: busybox-$(BBVER)
	@echo "	Building BusyBox"
	$(eval BUILDDIR := bb_build-$(BBVER)$(EXTRANAME))
	mkdir -p $(BUILDDIR)
	cd bb_build-$(BBVER)$(EXTRANAME) && $(MAKE) -f ../$(S_DIR)/buildandinstalbb.mk
	@echo "	done Install BB!"	

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

sudo_build-$(SUDOVER)$(EXTRANAME): sudo-$(SUDOVER) 
	@echo Building sudo
	$(eval BUILDDIRSUDO := sudo_build-$(SUDOVER)$(EXTRANAME))
	mkdir -p $(BUILDDIRSUDO)
	cd sudo_build-$(SUDOVER)$(EXTRANAME) && $(MAKE) -f ../$(S_DIR)/buildsudo.mk
	@echo "	done Build SUDO!"	

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