**Description**  
A script designed to minimize a Debian install.

**Compatibility**  

- **Operating Systems:**
  - Debian 6 (Squeeze) i686
  - Debian 6 (Squeeze) x86_64
- **Platforms:**
  - KVM
  - OpenVZ
  - Physical Hardware
  - VirtualBox
  - VMware
  - Xen HVM

**Credits**  

- cedr @ daIRC: General Help
- miTgiB @ daIRC: Script Help
- DPKG Cleaning: http://www.coredump.gr/linux/debian-package-list-backup-and-restore/
- SSH Limiting: http://www.hostingfu.com/article/ssh-dictionary-attack-prevention-with-iptables/


**Download**  
Download the script with the following command:

	cd ~; wget --no-check-certificate -O minimal.tar.gz http://www.github.com/maxexcloo/Minimal/tarball/master; tar zxvf minimal.tar.gz; cd *Minimal*

**Notes**  

- Run on a freshly installed server under root!
- Make sure you don't rely on sudo, you'll get locked out as it will be wiped during the cleaning process!

**Usage**  
You must run this script with options. They are outlined below:

- For a minimal Dropbear based install: `bash minimal.sh dropbear`
- For a minimal OpenSSH based install: `bash minimal.sh ssh`
- To install extra packages defined in the extra file: `bash minimal.sh extra`
- To set the clock, clean files and create a user: `bash minimal.sh configure`

**Warning**  
This repository is unsupported and code may be outdated or broken.
