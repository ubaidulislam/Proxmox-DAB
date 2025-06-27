BASEDIR:=$(shell dab basedir)

all: info/init_ok
	dab bootstrap --minimal
	# List of packages to install
	dab install sudo unattended-upgrades apt-listchanges locales dirmngr apt-transport-https gnupg2

	# Set locale
	echo "en_GB.UTF-8" > ${BASEDIR}/etc/locale
	echo "en_GB.UTF-8 UTF-8" > ${BASEDIR}/etc/locale.gen
	dab exec dpkg-reconfigure -f noninteractive locales

	# Set correct timezone
	echo "Europe/London" > ${BASEDIR}/etc/timezone
	dab exec cp /usr/share/zoneinfo/Europe/London /etc/localtime
	dab exec dpkg-reconfigure -f noninteractive tzdata

	# Create Ansible system user (-r), with a home directory (-m), bash as the
	# shell (-s /bin/bash) & with no password as it is not needed and place
	# place the SSH public keys in the relevant directory with passwordless sudo
	dab exec useradd -r -m -s /bin/bash ansible
	wget -O ${BASEDIR}/etc/ssh/authorized_keys_ansible https://github.com/ubaidulislam.keys
	mkdir ${BASEDIR}/etc/sudoers.d/
	touch ${BASEDIR}/etc/sudoers.d/ansible
	echo 'ansible ALL=(ALL) NOPASSWD: ALL' > ${BASEDIR}/etc/sudoers.d/ansible
	dab exec bash -c "chmod 440 /etc/sudoers.d/ansible"

	# Harden SSH - disable root login and use only public key authentication and point to keyfiles
	sed -i '/#PermitRootLogin prohibit-password/c PermitRootLogin no' ${BASEDIR}/etc/ssh/sshd_config ; \
	sed -i '/#PubkeyAuthentication yes/c PubkeyAuthentication yes' ${BASEDIR}/etc/ssh/sshd_config ; \
	sed -i '/#PasswordAuthentication yes/c PasswordAuthentication no' ${BASEDIR}/etc/ssh/sshd_config ; \
	sed -i '/#PermitEmptyPasswords no/c PermitEmptyPasswords no' ${BASEDIR}/etc/ssh/sshd_config ; \
	echo 'AuthorizedKeysFile /etc/ssh/authorized_keys_ansible' >> ${BASEDIR}/etc/ssh/sshd_config

	# Set up unattended upgrades
	dab exec echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
	dab exec dpkg-reconfigure -f noninteractive unattended-upgrades
	wget -O ${BASEDIR}/etc/apt/apt.conf.d/20auto-upgrades https://raw.githubusercontent.com/ubaidulislam/Proxmox-DAB/refs/heads/main/lxc/20auto-upgrades
	wget -O ${BASEDIR}/etc/apt/apt.conf.d/50unattended-upgrades https://raw.githubusercontent.com/ubaidulislam/Proxmox-DAB/refs/heads/main/lxc/50unattended-upgrades
	dab exec unattended-upgrades --dry-run

	# Clean up packages and build
	dab exec apt-get autoremove && apt-get clean
	dab finalize --compressor zstd-max

info/init_ok: dab.conf
	dab init
	touch $@

.PHONY: clean
clean:
	dab clean
	rm -f *~
	rm -rf debian-*

.PHONY: dist-clean
dist-clean:
	dab dist-clean
	rm -f *~
	rm -rf debian-*
