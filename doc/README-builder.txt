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



# Define your local, private, individual, not-project dependent  build setup
# in the file ~/.opsi-builder.cfg OR by using the environment variable OPSI_BUILDER
# pointing the the configuration.  
#    export OPSI_BUILDER=/home/dschwager/work/opsi-builder.cfg
# If no files are availble, the default values will be use 
# from <opsi-builder-home>/conf/opsi-builder.cfg 

  cp <opsi-builder-home>/conf/opsi-builder.cfg $HOME/.opsi-builder.cfg
  vi $HOME/.opsi-builder.cfg
     # may you will change some locations

# May you will add opsi-builder.sh to your PATH
  export PATH=$HOME/work/devtools/bin:$PATH

# Start building
  opsi-builder.sh <path-to-the-project>

  cd <path-to-the-project> ;  opsi-builder.sh

  You can overwrite all variables in opsi-builder.cfg by command, e.g. by
    # Force downloading vendor files 
    DIST_FORCE_DOWNLOAD=1 builder.sh /home/dschwager/work/itwatch

      # Force upload independent of existing OPSI-Package in repository
    OPSI_REPOS_FORCE_UPLOAD=1 builder.sh /home/dschwager/work/itwatch



