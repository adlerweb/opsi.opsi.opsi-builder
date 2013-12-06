##############################
# Prerequirements:
# - Setup your environment variable inside the shell, e.g. ~/.bashrc
#    export BUILD_LOCAL_CFG=/home/dschwager/work/build_local.cfg
#    check the sample build_local.cfg located inside the itwatch project
##############################

# requirements RHEL/Centos 6
     yum install -y unzip zip unix2dos
     yum install -y plowshare cabextract
     yum install -y ImageMagick
     yum install -y git ruby

# additional requirements (not available in normale RHEL/Centos 6 repos)
    set-ini (martINI)
    	  yum install python-setuptools
          # https://pypi.python.org/pypi/martINI for writing ini files
	  wget --no-check-certificate https://pypi.python.org/packages/source/m/martINI/martINI-0.4.tar.gz
	  tar xfvz martINI-0.4.tar.gz
	  cd martINI-0.4
	  python setup.py  install

    aria2c for torrent downloads
	   wget ftp://ftp.univie.ac.at/systems/linux/dag/redhat/el6/en/x86_64/dag/RPMS/aria2-1.16.4-1.el6.rf.x86_64.rpm
	   wget ftp://ftp.univie.ac.at/systems/linux/dag/redhat/el6/en/x86_64/dag/RPMS/nettle-2.2-1.el6.rf.x86_64.rpm
	   rpm -i aria2-*.rpm nettle-*.rpm

    lha		ftp://ftp.pbone.net/mirror/ftp5.gwdg.de/pub/opensuse/repositories/home:/sawaa/CentOS_CentOS-6/x86_64/lha-1.14i-2.ac20050924p1.el6.ikoi1.x86_64.rpm

    unrar	http://pkgs.repoforge.org/unrar/unrar-4.0.7-1.el6.rf.x86_64.rpm

    7zip	check README-7zip.txt


# Please check the conf/opsi-builder.conf for detailed information
  	 cp conf/opsi-builder.conf $HOME/.opsi-builder.conf
	 emacs -nw $HOME/.opsi-builder.conf

# May you will add opsi-builder.sh to your PATH
  export PATH=$HOME/work/devtools/bin:$PATH

# You will find additional information inside the sample configuration
# Please read the file carefully
      <opsi-builder-home>/sample/*

# Start building
  opsi-builder.sh <path-to-the-project>

  cd <path-to-the-project> ;  opsi-builder.sh

  You can overwrite all variables in opsi-builder.cfg by command, e.g. by
    # Force downloading vendor files 
    DIST_FORCE_DOWNLOAD=1 builder.sh /home/dschwager/work/itwatch

      # Force upload independent of existing OPSI-Package in repository
    OPSI_REPOS_FORCE_UPLOAD=1 builder.sh /home/dschwager/work/itwatch



