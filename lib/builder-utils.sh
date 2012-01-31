#############################################
# void retrieve_file (src, dst)
#
# Description: retrieve file from an URL
# 
# Parameter
#  downloader: program to download the files
#  src: source url to get file from
#  dst: path to store file to
#
#############################################
function  retrieve_file() {
    local downloader=$1
    local src=$2
    local dst=$3

    # Check, if the URL is a file URL starting with file://
    if [ -f $dst ] && [ -z ${DIST_FORCE_DOWNLOAD} ]; then
	echo "  Info: File still cached/downloaded. To force a download, set DIST_FORCE_DOWNLOAD=1"
    elif [[ $src == file://* ]]; then
	fileurl=`echo $src | sed "s/^file:\/\///"`
	cp  $fileurl $dst  2>/dev/null
    else
	rm -f $dst
	if [ "$downloader" = "wget" ]; then
	    wget  --tries=1 -O $dst --timeout=5 -q --no-verbose "$src"
	    if [ "$?" == "1" ] ; then
		rm $dst
	    fi
	elif [ "$downloader" = "plowdown" ]; then
	    fatal_error "plowdown not implemented yet"
	else
	    fatal_error "Downloader not implemented: $downloader"
	fi
    fi  
}

#############################################
# void extract_file (format, src, dst)
#
# Description: Extract a file
# 
# Parameter
#  format: compression format
#  src: source file to be used
#  dst: path to extract the file
#
#############################################
function  process_file() {

    local format=$1
    local src=$2
    local dst=$3
    
    log_debug "Compression format: $format"

    if [ "$format" = "cp" ]; then
	cp $src $dst
    elif [ "$format" = "7zip" ]; then
	7z x -o$dst $src
    elif [ "$format" = "unzip" ]; then
	unzip $src -d $dst
    else
	fatal_error "Unknown compression format: $format"
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
# Fata Error
###################
fatal_error() {
    echo "FATAL: $1"
    exit 0
}

###################
# Check error
###################
builder_check_error() {
    if [ "$?" == "1" ] ; then
	fatal_error "$1"
    fi
}

###################
# Logging Debug
###################
log_debug() {
    local str=$1

    if [ "$DEBUG_LEVEL" = "debug" ] ||  [ "$DEBUG_LEVEL" = "info" ]  ; then
	echo $str
    fi
}

###################
# Logging Info
###################
log_info() {
    local str=$1

    if [ "$DEBUG_LEVEL" = "info" ]  ; then
	echo $str
    fi
}

###################
# Convert image
###################
convert_image() {
    local src=$1
    local dst=$2

    local hight=`identify -format "%h" $src`
    local wight=`identify -format "%w" $src`
    identify -format "%wx%h" $src

    if [ $wight -lt $hight ] ; then
	# Its higher so force x160 and let imagemagic decide the right wight
	# then add transparency to the rest of the image to fit 160x160
	log_debug "Icon Wight: $wight < Hight: $hight"
	convert $src -transparent white -background transparent -resize x160 \
	    -size 160x160 xc:transparent +swap -gravity center -composite $dst
	builder_check_error "converting image"
    elif [ $wight -gt $hight ] ; then
	# Its wider so force 160x and let imagemagic decide the right hight
	# then add transparency to the rest of the image to fit 160x160
	log_debug "Icon Wight: $wight > Hight: $hight"
	convert $src -transparent white -background transparent -resize 160x \
	    -size 160x160 xc:transparent +swap -gravity center -composite $dst
	builder_check_error "converting image"
    elif [ $wight -eq $hight ] ; then
	# Its scare so force 160x160
	log_debug "Icon Wight: $wight = Hight: $hight"
	convert $src -transparent white -background transparent -resize 160x160 \
	    -size 160x160 xc:transparent +swap -gravity center -composite $dst
	builder_check_error "converting image"
    else
	# Imagemagic is unable to detect the aspect ratio so just force 160x160
	# this could result in streched images
	log_debug "Icon Wight: $wight unknown Hight: $hight"
	convert $src -transparent white -background transparent -resize 160x160 \
	    xc:transparent +swap -gravity center -composite $dst
	builder_check_error "converting image"
    fi

    # New size
    # identify -format "%wx%h" $dst
    hight=`identify -format "%h" $dst`
    wight=`identify -format "%w" $dst`
    log_debug "Opsi Icon Wight: $wight  Hight: $hight"

}


###################
# Create variable file
#
# Create a file containing all important winst variables 
# (declaration and setings)
# 
# Parameter
#  file: file to create
#
###################
create_winst_varfile() {
    local var_file=$1

    echo -n >$var_file
    for (( i = 0 ; i < ${#DL_SOURCE[@]} ; i++ )) ; do
	if [ -z ${DL_WINST_NAME[$i]} ] ; then continue ; fi

	if [ ! -z "${DL_ARCH[$i]}" ] ; then arch_str="${DL_ARCH[$i]}\\" ; fi
	echo "DefVar \$${DL_WINST_NAME[$i]}\$" >>$var_file
	echo "Set    \$${DL_WINST_NAME[$i]}\$ = \"%ScriptPath%\\${arch_str}${DL_FILE[$i]}\""  >>$var_file
    done

    # publish some other variables
    for var in VENDOR PN VERSION RELEASE PRIORITY ADVICE TYPE CREATOR_TAG CREATOR_NAME CREATOR_EMAIL ; do 
        echo "DefVar \$${var}\$"            >>$var_file
        echo "Set    \$${var}\$ = \"${!var}\""  >>$var_file
    done

    # copy image and create variable
    echo "DefVar \$IconFile\$"  >>$var_file
    echo "Set    \$IconFile\$ = \"%ScriptPath%\\`basename $ICONFILE`\"" >>$var_file

    # publish custom variables
    for (( i = 0 ; i < ${#WINST_NAME[@]} ; i++ )) ; do

	# replace DL_EXTRACT_WINST_PATH
	local index=`echo ${WINST_VALUE[$i]} | sed -e "s#.*@DL_EXTRACT_WINST_PATH\[\([0-9]\)\]@.*#\1#"`
	log_debug "calculated (DL_EXTRACT_WINST_PATH), Index: $index"
	if [ "$index" != "${WINST_VALUE[$i]}" ] ; then
	    if [ ! -z "${DL_ARCH[$index]}" ] ; then arch_part="\\\\${DL_ARCH[$index]}" ; fi
	    if [ ! -z "${DL_EXTRACT_WINST_PATH[$index]}" ] ; then extr_part="\\\\${DL_EXTRACT_WINST_PATH[$index]}" ; fi
	    local new_val="%ScriptPath%$arch_part$extr_part"
	    WINST_VALUE[$i]=`echo ${WINST_VALUE[$i]} | sed -e "s#@DL_EXTRACT_WINST_PATH\[[0-9]\]@#$new_val#"`
	    log_debug "calculated (DL_EXTRACT_WINST_PATH) WINST_VALUE: ${WINST_VALUE[$i]}"
	fi

	echo "DefVar \$${WINST_NAME[$i]}\$" >>$var_file
	echo "Set    \$${WINST_NAME[$i]}\$ = \"${WINST_VALUE[$i]}\""  >>$var_file
    done

    echo >>$var_file
}
