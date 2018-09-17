# OPSI-Builder

*OPSI-Builder* is a framework for generating *[OPSI](https://www.opsi.org)*-packages. *OPSI* is a software distribution and management system. 

## Prerequirements:
 * Setup your environment variable inside the shell, e.g. ~/.bashrc
 * export BUILD_LOCAL_CFG=/home/dschwager/work/build_local.cfg
 *  check the sample build_local.cfg located inside the itwatch project

### requirements Dabian/Ubuntu
````
apt install p7zip-full zip unzip unrar tar cabextract dos2unix imagemagick zsync coreutils python-pip ruby gpg
pip install martINI
````

### requirements RHEL/Centos 6
     yum install -y unzip zip unix2dos
     yum install -y plowshare cabextract
     yum install -y ImageMagick
     yum install -y git ruby

#### additional requirements (not available in normale RHEL/Centos 6 repos)
 * set-ini (martINI)
````
yum install python-setuptools
wget https://pypi.python.org/packages/source/m/martINI/martINI-0.4.tar.gz
tar xfvz martINI-0.4.tar.gz
cd martINI-0.4
python setup.py  install
````
* aria2c for torrent downloads
````
	   wget ftp://ftp.univie.ac.at/systems/linux/dag/redhat/el6/en/x86_64/dag/RPMS/aria2-1.16.4-1.el6.rf.x86_64.rpm
	   wget ftp://ftp.univie.ac.at/systems/linux/dag/redhat/el6/en/x86_64/dag/RPMS/nettle-2.2-1.el6.rf.x86_64.rpm
	   rpm -i aria2-*.rpm nettle-*.rpm
````
* lha ````ftp://ftp.pbone.net/mirror/ftp5.gwdg.de/pub/opensuse/repositories/home:/sawaa/CentOS_CentOS-6/x86_64/lha-1.14i-2.ac20050924p1.el6.ikoi1.x86_64.rpm````
* unrar	````http://pkgs.repoforge.org/unrar/unrar-4.0.7-1.el6.rf.x86_64.rpm````
* 7zip	````check README-7zip.txt````


## Configuration
Please check conf/opsi-builder.conf for detailed information. You can copy the file to your home directory for local changes.
````
cp conf/opsi-builder.conf ~/.opsi-builder.conf
vim ~/.opsi-builder.conf
````
## Using OPSI-Builder
You might want to add the path to opsi-builder.sh to your environments PATH
````export PATH=$HOME/dev/opsi-builder/bin:$PATH````

Now enter a package directory. You'll find various examples on how a directory should look like in our repository or the *sample*-Directory.

Now start the stript
````opsi-builder.sh````

Without arguments *opsi-builder* will search the current working directory for package configurations. You also can supply a path to the project instead.

````opsi-builder-sh <path-to-the-project>````

You can overwrite all variables in opsi-builder.cfg using environment variables, e.g.
````
# Force downloading vendor files 
DIST_FORCE_DOWNLOAD=1 builder.sh ~/dev/itwatch
# Force upload independent of existing OPSI-Package in repository
OPSI_REPOS_FORCE_UPLOAD=1 builder.sh ~/dev/itwatch
