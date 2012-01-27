##############################################################################
# This optional file "builder-targets-cb.sh" will be called by builder.sh 
# 
# You can overwrite target functions like
#   config, prepare, retrieve, create, package, publish, commit, cleanup
# and  define callback functions 
#   cb_package_makeproductfile
#
##############################################################################

#function config() {
#    echo "Config" 
#    builder_config
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
