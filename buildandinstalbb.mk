DIR = ../../Progetto
CONFIG_FILE := $(DIR)/Configs/config-busybox-2

all:
	@echo "	configuring... "
	cp $(CONFIG_FILE) .config
	make -C $(shell pwd)/../busybox-$(BBVER)$(EXTRANAME) CC="$(MCROSS)$(CC)" CROSS_COMPILE=$(MCROSS) O=$(shell pwd) oldconfig  > config_bb.log 2> config_bb.err 
	@echo "done!"
	@echo "	compiling..."

	@echo CPUS is $(CPUS)
	make -j $(CPUS) V=1       CC="$(MCROSS)$(CC)" CROSS_COMPILE=$(MCROSS)                     > build_bb.log  2> build_bb.err
	@echo "	done Build BB!"

	@echo "	Installing BusyBox"
	rm -rf _install
	make install V=1     CC="$(MCROSS)$(CC)" CROSS_COMPILE=$(MCROSS)                     > install_bb.log 2> install_bb.err
	@echo "	done Install BB!"