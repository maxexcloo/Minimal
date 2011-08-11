#!/bin/bash
# CREDITS: maxexcloo @ www.excloo.com
cd $(dirname $0)
unset HISTFILE

###############
## Variables ##
###############

SSHPORT=""

#############################
## Configuration Functions ##
#############################

# Runs Through Configuration Functions
function configure_basic {
	# Configure Defaults
	configure_defaults

	# Remove Useless Gettys
	configure_getty

	# Ask If BASH History Should Be Disabled
	echo -n "Do you wish to disable BASH history? (Y/n): "
	read -e OPTION_HISTORY
	if [ "$OPTION_HISTORY" != "n" ]; then
		configure_history
	fi

	# Ask If SSH Port Should Be Changed
	echo -n "Do you wish to run SSH on different ports? (y/N): "
	read -e OPTION_SSHPORT
	if [ "$OPTION_SSHPORT" == "y" ]; then
		configure_sshport
	fi

	# Ask If SSH Logins Should Be Rate Limited
	echo -n "Do you wish to rate limit SSH? (y/N): "
	read -e OPTION_SSHRATE
	if [ "$OPTION_SSHRATE" == "y" ]; then
		configure_sshrate
	fi

	# Ask If Root SSH Should Be Disabled
	echo -n "Do you wish to disable root SSH logins? Keep enabled if you don't plan on making any users! (Y/n): "
	read -e OPTION_SSHROOT
	if [ "$OPTION_SSHROOT" == "y" ]; then
		configure_sshroot
	fi

	# Ask If Time Zone Should Be Set
	echo -n "Do you wish to set the timezone? (Y/n): "
	read -e OPTION_TZ
	if [ "$OPTION_TZ" != "n" ]; then
		configure_timezone
	fi

	# Ask If User Should Be Made
	echo -n "Do you wish to create a user account? (Y/n): "
	read -e OPTION_USER
	if [ "$OPTION_USER" != "n" ]; then
		configure_user
	fi

	# Clean Up
	configure_final
}

# Overwrites Server Skel Directory With Template Skel Directory
function configure_defaults {
	# Prints Informational Message
	echo \>\> Configuring: Defaults
	# Remove Home Dotfiles
	rm -rf ~/.??*
	# Remove Skel Dotfiles
	rm -rf /etc/skel/.??*
	# Update Home Dotfiles
	cp -a -R settings/skel/.??* ~
	# Update Skel Dotfiles
	cp -a -R settings/skel/.??* /etc/skel
}

# Cleans Home Folder (Removes Script)
function configure_final {
	# Prints Informational Message
	echo \>\> Configuring: Finalizing
	# Remove All Home Files
	rm -rf ~/*
	# Remove Aptitude Cache Directory
	rm -rf ~/.aptitude
	# Remove Local SSH Directory
	rm -rf ~/.ssh
	# Remove Skel SSH Directory
	rm -rf /etc/skel/.ssh
}

# Configures Miscellaneous Options
function configure_getty {
	# Prints Informational Message
	echo \>\> Configuring: Gettys
	# Removes Useless Gettys
	sed -e 's/\(^[2-6].*getty.*\)/#\1/' -i /etc/inittab
}

# Disables BASH History
function configure_history {
	# Prints Informational Message
	echo \>\> Configuring: BASH History
	# Sets Variable To Turn Off Bash History
	echo "unset HISTFILE" >> /etc/profile
}

# Changes SSH Port To User Specification
function configure_sshport {
	# Prints Informational Message
	echo \>\> Configuring: Changing SSH Ports
	# Takes User Name Input
	echo -n "Please enter an additional SSH Port: "
	read -e SSHPORT
	# Adds Port
	sed -i 's/#Port/Port '$SSHPORT'/g' /etc/ssh/sshd_config
	sed -i 's/DROPBEAR_EXTRA_ARGS="-w/DROPBEAR_EXTRA_ARGS="-w -p '$SSHPORT'/g' /etc/default/dropbear
}

# Enables SSH Login Rate Limiting
function configure_sshrate {
	# Prints Informational Message
	echo \>\> Configuring: Rate Limiting SSH Logins
	# Enables SSH Login Rate Limiting
	iptables -N SSH_CHECK
	iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j SSH_CHECK
	if [ "$SSHPORT" != "" ]; then
		iptables -A INPUT -p tcp --dport $SSHPORT -m state --state NEW -j SSH_CHECK
	fi
	iptables -A SSH_CHECK -m recent --set --name SSH
	iptables -A SSH_CHECK -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
	# Saves Limits
	iptables-save > /etc/firewall.conf
	echo '#!/bin/sh' > /etc/network/if-up.d/iptables
	echo "iptables-restore < /etc/firewall.conf" >> /etc/network/if-up.d/iptables
	chmod +x /etc/network/if-up.d/iptables
}

# Enables Root SSH Login
function configure_sshroot {
	# Prints Informational Message
	echo \>\> Configuring: Enabling Root SSH Login
	# Enables Root SSH Login
	sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
	sed -i 's/"-w/"/g' /etc/default/dropbear
	sed -i 's/" /"/g' /etc/default/dropbear
}

# Sets Time Zone
function configure_timezone {
	# Prints Informational Message
	echo \>\> Configuring: Time Zone
	# Shows Option To Set Time Zone
	dpkg-reconfigure tzdata
}

# Adds User Account
function configure_user {
	# Prints Informational Message
	echo \>\> Configuring: User Account
	# Takes User Name Input
	echo -n "Please enter a user name: "
	read -e USERNAME
	# Add User
	useradd -m $USERNAME
	# Set Password
	passwd $USERNAME
}

############################
## Installation Functions ##
############################

# Runs Through Install Functions
function install_basic {
	# Run Functions In Order
	packages_update
	packages_purge
	packages_minimal
	packages_dpkg
	packages_purge
}

# Installs Lightweight Dropbear SSH Server & OpenSSH For SFTP Support
function install_dropbear {
	# Prints Informational Message
	echo \>\> Configuring Dropbear
	# Installs Dropbear
	aptitude install dropbear
	# Updates Configuration Files
	cp settings/dropbear /etc/default/dropbear
	# Installs OpenSSH For SFTP Support
	install_ssh
	# Removes OpenSSH Daemon
	update-rc.d -f ssh remove
	# Cleans Package List
	packages_purge
}

# Installs Extra Packages Defined In List
function install_extra {
	# Loops Through Package List
	while read package; do
		# Installs Currently Selected Package (true | fixes a bug caused by input being stdin)
		true | aptitude install $package
	done < lists/extra
	# Cleans Cached Packages
	aptitude clean
}

# Installs OpenSSH And Sets Configuration
function install_ssh {
	# Prints Informational Message
	echo \>\> Configuring SSH
	# Installs OpenSSH
	aptitude install openssh-server
	# Updates Configuration Files
	cp settings/sshd /etc/ssh/sshd_config
	cp settings/ssh /etc/ssh/ssh_config
	# Restarts OpenSSH Daemon
	/etc/init.d/ssh restart
	# Cleans Package List
	packages_purge
}

#######################
## Package Functions ##
#######################

# Uses DPKG To Remove Packages The Minimal Script Has Missed
function packages_dpkg {
	# Prints Informational Message
	echo \>\> Updating DPKG
	# Clear DPKG Package Selections
	dpkg --clear-selections
	# Check For OpenVZ Server
	if [ -f /proc/user_beancounters ] || [ -d /proc/bc ]; then
		# Set OpenVZ Package Selections
		dpkg --set-selections < lists/minimal-dpkg
	else
		# Set KVM Package Selections
		dpkg --set-selections < lists/minimal-kvm-dpkg
	fi
	# Install/Remove To Make System Match Package List
	aptitude install
	# Upgrade Any Outdated Packages
	aptitude upgrade
}

# Uses A Bash Script To Purge Unneeded Packages And Settings
function packages_minimal {
	# Prints Informational Message
	echo \>\> Purging Non Minimal Packages
	# Check For OpenVZ Server
	if [ -f /proc/user_beancounters ] || [ -d /proc/bc ]; then
		# Copy OpenVZ Package List
		cp lists/minimal lists/temp
	else
		# Copy KVM Package List
		cp lists/minimal-kvm lists/temp
	fi
	# Run Package Cleaning Script
	sh cpac.sh
	# Upgrade Any Outdated Packages
	aptitude upgrade
}

# Purges APT/Aptitude Package Lists & Old Packages
function packages_purge {
	# Prints Informational Message
	echo \>\> Cleaning Package States
	# Empty Package List Files
	echo -n > /var/lib/apt/extended_states
	echo -n > /var/lib/aptitude/pkgstates
	echo -n > /var/lib/aptitude/pkgstates.old
	# Cleans Cached Packages
	aptitude clean
}

# Updates Sources List & APT
function packages_update {
	# Prints Informational Message
	echo \>\> Setting Up APT Sources
	# Copies Sources
	cp settings/sources /etc/apt/sources.list
	# Adds DotDeb Source Key
	wget http://www.dotdeb.org/dotdeb.gpg -qO - | apt-key add -
	# Updates Package Lists
	apt-get update
}

#################
## Init Script ##
#################

case "$1" in
	# Minimises System And Installs Dropbear
	dropbear)
		install_basic
		install_dropbear
	;;
	# Installs Extra Packages
	extra)
		install_extra
	;;
	# Configures Install
	configure)
		configure_basic
	;;
	# Minimises System And Installs OpenSSH
	ssh)
		install_basic
		install_ssh
	;;
	# Shows Help
	*)
		echo \>\> You must run this script with options. They are outlined below:
		echo For a minimal Dropbear based install: sh minimal.sh dropbear
		echo For a minimal OpenSSH based install: sh minimal.sh ssh
		echo To install extra packages defined in lists/extra: sh minimal.sh extra
		echo To set the clock, clean files and create a user: sh minimal.sh configure
	;;
esac
