DIR = ../../Progetto

all:
	@echo "	configuring... "
	CC=$(MCROSS)"$(CC)" ../sudo-$(SUDOVER)$(EXTRANAME)/configure --prefix=/ --disable-authentication --disable-shadow --disable-pam-session --disable-zlib --without-lecture --without-sendmail --without-umask --without-interfaces --without-pam --enable-static --disable-shared --enable-static-sudoers $(CROSS) > config_sudo.log 2> config_sudo.err
	@echo "done!"
	@echo "	compiling... "
	make -j $(CPUS) CC=$(MCROSS)"$(CC)"                 > build_sudo.log 2> build_sudo.err
	@echo "done Build SUDO!"