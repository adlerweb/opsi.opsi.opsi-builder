#!/bin/bash
#
#

# enabled debug
# set -x

#####################
# Controller
####################
builder_controller() {
  local result
  
  # read config
  call_entry_point  result config;    (( $result == "0" )) || builder_config
  
  # prepare
  call_entry_point  result prepare ;  (( $result == "0" )) || builder_prepare
  
  # download and process dist files
  call_entry_point  result retrieve;  (( $result == "0" )) || builder_retrieve
  
  # Create some special files
  call_entry_point  result create;    (( $result == "0" )) || builder_create
  
  # Start packaging
  call_entry_point  result package; (( $result == "0" )) || builder_package
  
  # Upload to repos
  call_entry_point  result publish; (( $result == "0" )) || builder_publish
  
  # git commit
  call_entry_point  result commit;  (( $result == "0" )) || builder_commit
  
  # cleanup
  call_entry_point  result cleanup;  (( $result == "0" )) || builder_cleanup
}

####################
# Main
####################
# get the 'real' directory this program stored in (resolve symbolic links)
PRG=$(readlink -f $0)
BASEDIR=`dirname "$PRG"`
BASEDIR=`cd "$BASEDIR" && pwd`/..

# Parameters
PRODUCT_DIR=$1
TARGET=$2

# read libraries
. $BASEDIR/lib/builder-targets.sh

# check product directory
if [ -z ${PRODUCT_DIR}  ]; then PRODUCT_DIR="`pwd`" ; fi
test -d $PRODUCT_DIR
builder_check_error "no opsi product directory specified: $PRODUCT_DIR"

# source additional, product dependent callback (cb) targets
if [ -f "$PRODUCT_DIR/builder-targets-cb.sh" ] ; then
  . "$PRODUCT_DIR/builder-targets-cb.sh"
fi

# call main
builder_controller

# exit
exit 0

