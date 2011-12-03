#!/bin/bash
cd $(dirname $0)

###############
## Variables ##
###############

# Disable BASH History For Session
unset HISTFILE

#############################
## Configuration Functions ##
#############################

# Run Through Configuration Functions
function configure_basic {
	# Configure Defaults
	configure_defaults

	# Remove Useless Gettys
	configure_getty

	# Ask If BASH History Should Be Disabled
	echo -n "Do you wish to disable BASH history? (Y/n): "
	read -e OPTION_HISTORY
	# Check User Input
	if [ "$OPTION_HISTORY" != "n" ]; then
		# Execute Function
		configure_history
	fi

	# Ask If Logging Should Be Simplified
	echo -n "Simplify logging configuration? (Y/n): "
	read -e OPTION_LOGGING
	# Check User Input
	if [ "$OPTION_LOGGING" != "n" ]; then
		# Execute Function
		configure_logging
	fi

	# Ask If SSH Port Should Be Changed
	echo -n "Do you wish to run SSH on different ports? (y/N): "
	read -e OPTION_SSHPORT
	# Check User Input
	if [ "$OPTION_SSHPORT" == "y" ]; then
		# Execute Function
		configure_sshport
	fi

	# Ask If Root SSH Should Be Disabled
	echo -n "Do you wish to disable root SSH logins? Keep enabled if you don't plan on making any users! (Y/n): "
	read -e OPTION_SSHROOT
	# Check User Input
	if [ "$OPTION_SSHROOT" != "n" ]; then
		# Execute Function
		configure_sshroot
	fi

	# Ask If Time Zone Should Be Set
	echo -n "Do you wish to set the timezone? (Y/n): "
	read -e OPTION_TZ
	# Check User Input
	if [ "$OPTION_TZ" != "n" ]; then
		# Execute Function
		configure_timezone
	fi

	# Ask If User Should Be Made
	echo -n "Do you wish to create a user account? (Y/n): "
	read -e OPTION_USER
	# Check User Input
	if [ "$OPTION_USER" != "n" ]; then
		# Execute Function
		configure_user
	fi

	# Reconfigure Dash
	dpkg-reconfigure dash

	# Clean Up
	configure_final
}

# Clean Dotfiles
function configure_defaults {
	echo \>\> Configuring: Defaults
	# Remove Home Dotfiles
	rm -rf ~/.??*
	# Remove Skel Dotfiles
	rm -rf /etc/skel/.??*
	# Update Home Dotfiles
	cp -a -R settings/skel/.??* ~
	# Update Skel Dotfiles
	cp -a -R settings/skel/.??* /etc/skel
	# Append Umask
	echo -e "\numask o=" >> /etc/skel/.bashrc
}

# Clean Home
function configure_final {
	echo \>\> Configuring: Finalizing
	# Remove All Home Files
	rm -rf ~/*
}

# Clean Getty
function configure_getty {
	echo \>\> Configuring: Gettys
	# Remove Unneeded Getty Instances
	sed -e 's/\(^[2-6].*getty.*\)/#\1/' -i /etc/inittab
}

# Disable BASH History
function configure_history {
	echo \>\> Configuring: BASH History
	# Disable System BASH History
	echo -e "\nunset HISTFILE" >> /etc/profile
}

# Simplify Logging
function configure_logging {
	echo \>\> Configuring: Simplified Logging
	# Stop Logging Daemon
	/etc/init.d/inetutils-syslogd stop
	# Remove Log Files
	rm /var/log/* /var/log/*/*
	rm -rf /var/log/news
	# Create New Log Files
	touch /var/log/{auth,daemon,kernel,mail,messages}
	# Copy Simplified Logging Configuration
	cp settings/syslog /etc/syslog.conf
	# Copy Simplified Log Rotation Configuration
	cp settings/logrotate /etc/logrotate.d/inetutils-syslogd
	# Start Logging Daemon
	/etc/init.d/inetutils-syslogd start
}

# Add Additional SSH Port
function configure_sshport {
	echo \>\> Configuring: Changing SSH Ports
	# Take User Input
	echo -n "Please enter an additional SSH Port: "
	read -e SSHPORT
	# Add Extra SSH Port To OpenSSH
	sed -i 's/#Port/Port '$SSHPORT'/g' /etc/ssh/sshd_config
	# Add Extra SSH Port To Dropbear
	sed -i 's/DROPBEAR_EXTRA_ARGS="-w/DROPBEAR_EXTRA_ARGS="-w -p '$SSHPORT'/g' /etc/default/dropbear
}

# Disable Root SSH Login
function configure_sshroot {
	echo \>\> Configuring: Disabling Root SSH Login
	# Disable Root SSH Login For OpenSSH
	sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
	# Disable Root SSH Login For Dropbear
	sed -i 's/DROPBEAR_EXTRA_ARGS="/DROPBEAR_EXTRA_ARGS="-w/g' /etc/default/dropbear
}

# Set Time Zone
function configure_timezone {
	echo \>\> Configuring: Time Zone
	# Configure Time Zone
	dpkg-reconfigure tzdata
}

# Add User Account
function configure_user {
	echo \>\> Configuring: User Account
	# Take User Input
	echo -n "Please enter a user name: "
	read -e USERNAME
	# Add User Based On Input
	useradd -m -s /bin/bash $USERNAME
	# Set Password For Newly Added User
	passwd $USERNAME
}

############################
## Installation Functions ##
############################

# Execute Install Functions
function install_basic {
	packages_update
	packages_purge
	packages_create
	packages_clean
	packages_purge
}

# Install Lightweight Dropbear SSH Server & OpenSSH For SFTP Support
function install_dropbear {
	echo \>\> Configuring Dropbear
	# Install Dropbear
	apt-get install dropbear
	# Update Configuration Files
	cp settings/dropbear /etc/default/dropbear
	# Install OpenSSH For SFTP Support
	install_ssh
	# Remove OpenSSH Daemon
	update-rc.d -f ssh remove
	# Clean Package List
	packages_purge
}

# Install Extra Packages Defined In List
function install_extra {
	# Loop Through Package List
	while read package; do
		# Install Currently Selected Package
		apt-get -q -y install $package
	done < extra
	# Clean Cached Packages
	apt-get clean
}

# Install OpenSSH & Sets Configuration
function install_ssh {
	echo \>\> Configuring SSH
	# Install OpenSSH
	apt-get install openssh-server
	# Copy SSH Configuration Files
	cp settings/sshd /etc/ssh/sshd_config
	cp settings/ssh /etc/ssh/ssh_config
	# Restart OpenSSH Daemon
	/etc/init.d/ssh restart
	# Clean Package List
	packages_purge
}

#######################
## Package Functions ##
#######################

# Use DPKG To Remove Packages
function packages_clean {
	echo \>\> Cleaning Packages
	# Clear DPKG Package Selections
	dpkg --clear-selections
	# Set Package Selections
	dpkg --set-selections < lists/temp
	# Get Selections & Set To Purge
	dpkg --get-selections | sed -e 's/deinstall/purge/' > /tmp/dpkg
	# Set Package Selections
	dpkg --set-selections < /tmp/dpkg
	# Update DPKG
	apt-get dselect-upgrade
	# Upgrade Any Outdated Packages
	apt-get upgrade
}

# Create Package List
function packages_create {
	echo \>\> Creating Package List
	# Copy Base Package List
	cp lists/base lists/temp
	# OpenVZ Check
	if [ -f /proc/user_beancounters ] || [ -d /proc/bc ]; then
		echo Detected OpenVZ!
	# Physical Hardware/Hardware Virtualisation
	else
		# Copy Base Package List
		cat lists/base-hw >> lists/temp
		# Detect x86
		if [ $(uname -m) == "i686" ]; then
			echo Detected i686!
			# Append Platform Relevent Packages To Package List
			cat lists/kernel-i686 >> lists/temp
		fi
		# Detect x86_64
		if [ $(uname -m) == "x86_64" ]; then
			echo Detected x86_64!
			# Append Platform Relevent Packages To Package List
			cat lists/kernel-x86_64 >> lists/temp
		fi
		# Detect XEN PV x86
		if [[ $(uname -r) == *xen* ]] && [ $(uname -m) == "i686" ]; then
			echo Detected XEN PV i686!
			# Append Platform Relevent Packages To Package List
			cat lists/kernel-xen-i686 >> lists/temp
		fi
		# Detect XEN PV x86_64
		if [[ $(uname -r) == *xen* ]] && [ $(uname -m) == "x86_64" ]; then
			echo Detected XEN PV x86_64!
			# Append Platform Relevent Packages To Package List
			cat lists/kernel-xen-x86_64 >> lists/temp
		fi
	fi
	# Sort Package List
	sort -o lists/temp lists/temp
}

# Purge APT Package Lists
function packages_purge {
	echo \>\> Cleaning Package States
	# Empty Package List Files
	echo -n > /var/lib/apt/extended_states
	# Clean Cached Packages
	apt-get clean
}

# Update Sources List & APT
function packages_update {
	echo \>\> Setting Up APT Sources
	# Copy Sources
	cp settings/sources /etc/apt/sources.list
	# Add DotDeb Source Key
	wget http://www.dotdeb.org/dotdeb.gpg -qO - | apt-key add -
	# Update Package Lists
	apt-get update
}

#################
## Init Script ##
#################

case "$1" in
	# Minimise System & Install Dropbear
	dropbear)
		install_basic
		install_dropbear
	;;
	# Install Extra Packages
	extra)
		install_extra
	;;
	# Configure Install
	configure)
		configure_basic
	;;
	# Minimise System & Install OpenSSH
	ssh)
		install_basic
		install_ssh
	;;
	# Show Help
	*)
		echo \>\> You must run this script with options. They are outlined below:
		echo For a minimal Dropbear based install: bash minimal.sh dropbear
		echo For a minimal OpenSSH based install: bash minimal.sh ssh
		echo To install extra packages defined in the extra file: bash minimal.sh extra
		echo To set the clock, clean files and create a user: bash minimal.sh configure
	;;
esac
