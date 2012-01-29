#############################################
# void retrieve_file (src, dst)
#
# Description: retrieve file from an URL
# 
# Parameter
#  src: source url to get file from
#  dst: path to store file to
#
#############################################
function  retrieve_file() {
    local src=$1
    local dst=$2

    # Check, if the URL is a file URL starting with file://
    if [ -f $dst ] && [ -z ${DIST_FORCE_DOWNLOAD} ]; then
	echo "  Info: File still cached/downloaded. To force a download, set DIST_FORCE_DOWNLOAD=1"
    elif [[ $src == file://* ]]; then
	fileurl=`echo $src | sed "s/^file:\/\///"`
	cp  $fileurl $dst  2>/dev/null
    else
	rm -f $dst
	wget  --tries=1 -O $dst --timeout=5 -q --no-verbose $src
    fi  
}

#############################################
# void extract_file (src, dst)
#
# Description: Extract a file
# 
# Parameter
#  src: source file to be used
#  dst: path to extract the file
#
#############################################
function  extract_file() {
    local src=$1
    local dst=$2

    if [ "${EXTRACTWITH}" = "7zip" ]; then
	7z x -o$dst $src
    elif [ "${EXTRACTWITH}" = "unzip" ]; then
	unzip $src -d $dst
    else
	7z x -o$dst $src
    fi  
}


#############################################
# check if method is available and call it
#############################################
function  call_entry_point() {
    local _resultvar=$1
    local func=$2
      
    # Entry point
    type $func &>/dev/null
    if [ $? == 0 ] ; then 
	$func
	eval $_resultvar="0"
    else
	eval $_resultvar="1"
    fi

}


###################
# Check error
###################
builder_check_error() {
    if [ $? == 1 ] ; then
	echo "FATAL: $1"
	exit 0
    fi
}

