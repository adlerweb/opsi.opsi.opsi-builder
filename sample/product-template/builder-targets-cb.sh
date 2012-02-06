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
#  callbacks: <none>
#
##############################################################################

function cleanup() {
    echo "Cleanup"
    builder_cleanup
}
