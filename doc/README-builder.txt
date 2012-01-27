##############################
# Prerequirements:
# - Setup your environment variable inside the shell, e.g. ~/.bashrc
#    export BUILD_LOCAL_CFG=/home/dschwager/work/build_local.cfg
#    check the sample build_local.cfg located inside the itwatch project
##############################

# requirements
     yum install plowshare
     yum install ImageMagick
     yum install git

# Define your local, private, individual, not-project dependent  build setup
# in the file ~/.builder.cfg OR by using the environment variable BUILD_LOCAL_CFG
# pointing the the configuration.  
#    export BUILD_LOCAL_CFG=/home/dschwager/work/itwatch/build_local.cfg 
# If no files are availble, the default values will be use.

# Start build
  builder.sh <path-to-the-project>
  builder.sh /home/dschwager/work/itwatch

  # Force downloading vendor files 
  DIST_FORCE_DOWNLOAD=1 builder.sh /home/dschwager/work/itwatch

  # Force upload independent of existing OPSI-Package in repository
  OPSI_REPOS_FORCE_UPLOAD=1 builder.sh /home/dschwager/work/itwatch


