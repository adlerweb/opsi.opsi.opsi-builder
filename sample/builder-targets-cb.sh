##############################################################################
# This optional file "builder-targets-cb.sh" will be called by builder.sh 
# 
# The targets will be called from thde opsi-builder using the following
# order: config, prepare, retrieve, create, package, publish, commit, cleanup 
# You can overwrite the target functions in builder-targets-cb.sh
# 
# You can define callback functions. The functions are called from
# opsi-builder within processing a target
#   cb_package_makeproductfile
#
# You can use every variable defined in any configuration file or by
# the defined builder script itself. Also, calling the predefined
# targets builder_<targetname> is possible.
#
# Abstract:
#  target order: config, prepare, retrieve, create, package, publish, commit, cleanup
#  callbacks: cb_package_makeproductfile
#
##############################################################################

#function config() {
#    echo "Config - doing some commands before calling the builder_config" 
#    builder_config
#    echo "Config - doing some commands after calling the builder_config" 
#}

#function prepare() { 
#    echo "Prepare" 
#    builder_prepare
#}

function retrieve() { 
    echo "Retrieve" 
    builder_retrieve
}

function create() { 
    echo  "Create"
    builder_create
}

function package() { 
    echo "Package" 
    builder_package
}

function cb_package_makeproductfile() {
    echo "May add/replace files to the files to $inst_dir"
}

function publish() {
    echo "Publish"
    builder_publish
}

function commit() {
    echo "Commit"
    # builder_commit
}
function cleanup() {
    echo "Cleanup: output_dir: $output_dir"
    # builder_cleanup
}
