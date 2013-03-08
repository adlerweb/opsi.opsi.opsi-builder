##############################
# Prerequirements:
# - Setup your environment variable inside the shell, e.g. ~/.bashrc
#    export BUILD_LOCAL_CFG=/home/dschwager/work/build_local.cfg
#    check the sample build_local.cfg located inside the itwatch project
##############################

# requirements for RHEL/Centos
     yum install plowshare
     yum install ImageMagick
     yum install git

# requirements
    https://pypi.python.org/pypi/martINI for writing ini files
    aria2c for torrent downloads
    cabextract
    lha
    unzip
    unrar

# Please check the conf/opsi-builder.conf for detailed information

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



