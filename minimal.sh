#!/bin/sh
# CREDITS: maxexcloo @ www.excloo.com
cd $(dirname $0)
unset HISTFILE

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
	# Finalizes Install
	final)
		configure_defaults
		configure_misc
		configure_user
		configure_final
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
		echo To set the clock, clean files and create a user: sh minimal.sh final
	;;
esac

#############################
## Configuration Functions ##
#############################

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
function configure_misc {
	# Prints Informational Message
	echo \>\> Configuring: Miscellaneous
	# Removes Useless Gettys (Not Used AFAIK)
	sed -e 's/\(^[2-6].*getty.*\)/#\1/' -i /etc/inittab
	# Sets Variable To Turn Off Bash History
	echo "unset HISTFILE" >> /etc/profile
}

# Sets Time Zone & Adds User Account
function configure_user {
	# Prints Informational Message
	echo \>\> Configuring: Time Zone
	# Shows Option To Set Time Zone
	dpkg-reconfigure tzdata
	# Prints Informational Message
	echo \>\> Configuring: User Account
	# Takes User Name Input
	echo -n Please Choose A User Name:
	read -e USERNAME
	# Add User Based On Input
	useradd $USERNAME
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
		# Installs Currently Selected Package
		aptitude install $package
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
