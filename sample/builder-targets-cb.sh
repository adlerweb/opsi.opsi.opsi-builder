##############################################################################
# This optional file "builder-targets-cb.sh" will be called by builder.sh 
# 
# You can overwrite target functions like
#   config, prepare, retrieve, create, package, publish, commit, cleanup
# 
# You can define callback functions like
#   cb_package_makeproductfile
#
# You can use every variable defined in any configuration file or by
# the defined builder script itself. Also, calling the predefined
# targets builder_<targetname> is possible.
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
