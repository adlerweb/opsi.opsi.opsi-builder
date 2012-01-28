#####################
# Call user entry point
####################

# source generic utility functions
. $BASEDIR/lib/builder-utils.sh

#####################
# Read config
####################
builder_config() {

    # Check temp dir
    test -d ${TMP_DIR}
    builder_check_error "temp directory not available: $TMP_DIR"
    
    # Source product release configuration
    test -f ${PRODUCT_DIR}/builder-product.cfg
    builder_check_error "can't read release configuration: ${PRODUCT_DIR}/product.cfg"
    . $PRODUCT_DIR/builder-product.cfg 
    
    # change some variable dynamically
    # - autogenerate release number, if we are in status "integration"
    if [ "$STATUS" = "integration" ] ; then
	# OPSI/control:RELEASE is limited to max 16 chars - take care in regards to the CREATOR_TAG
	RELEASE="`date +%Y%m%d%H%M`"
    fi

    # set default build configuration and source the user dependent file
    . $BASEDIR/conf/opsi-builder.cfg

    #  Source local build configuration (must be done AFTER sourcing the release.cfg)
    test -f $HOME/.opsi-builder.cfg && . $HOME/.opsi-builder.cfg && echo "Loaded builder configuration: $HOME/.opsi-builder.cfg"
    test -f "$OPSI_BUILDER"  && . $OPSI_BUILDER &&  echo "Loaded builder configuration: $OPSI_BUILDER"
    
    # Check variables
    if [ -z ${OPSI_REPOS_BASE_DIR} ] || [ ! -d ${OPSI_REPOS_BASE_DIR} ] ; then
	echo "configuration error: OPSI_REPOS_BASE_DIR directory does not exist: $OPSI_REPOS_BASE_DIR"
	exit 2
    fi

}

#####################
# Prepare build
####################
builder_prepare() {

    # Check if the package is still build
    if  [ -z "$OPSI_REPOS_FORCE_UPLOAD" ] && [ -f ${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN} ]  ; then
	echo "ERROR:  package ${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN} already generated"
	exit 1
    fi

    mkdir -p $DIST_CACHE_DIR
    echo "Distribution directory: $DIST_CACHE_DIR"

    # setup work directory
    OUTPUT_DIR=$(mktemp -d $TMP_DIR/opsi-builder.XXXXXXXXXX) || { echo "Failed to create temp dir"; exit 1; }

}


#####################
# Download all dist files from one of the defined URLs. 
# and validate the checksum
####################
builder_retrieve() {

    for (( i = 0 ; i < ${#SOURCE[@]} ; i++ )) ; do
	local basename=${FILE[$i]}
	local urls=${SOURCE[$i]}
	local arch=${ARCH[$i]}
	local downloaded=0
	
        # Add private repos to the urls
	if [ ! -z ${DIST_PRIVATE_REPOS} ]; then
	    urls="${DIST_PRIVATE_REPOS}/$basename;$urls"
	fi
	
        # check existence of CRC file
	if [ ! -e ${PRODUCT_DIR}/${basename}.sha1sum ] ; then
	    echo "You need to create the checksums with: sha1sum ${DIST_CACHE_DIR}/${basename}  > ${PRODUCT_DIR}/${basename}.sha1sum"
	    exit 1
	fi
	
	echo "Downloading $basename"
        # check downloading from the defined URLs
	for src in `echo  $urls | sed -e 's/;/\n/g'`  ; do
	    if [ $downloaded == 1 ]; then continue; fi

	    echo "  Info: Downloding from $src"
	    mkdir -p ${DIST_CACHE_DIR}/$arch
	    DIST_FILE[$i]=${DIST_CACHE_DIR}/$arch/$basename
	    retrieve_file $src  ${DIST_FILE[$i]}

	    if [ $? == 0 ] ; then 
	        # testing the checksum of the downloaded files
		SHA1SUM=`cat ${PRODUCT_DIR}/${basename}.sha1sum | cut -d " " -f1`
		CHECKSUM=`sha1sum ${DIST_FILE[$i]} | cut -d " " -f1`
		if [ "$CHECKSUM" == "$SHA1SUM" ] ; then 
		    downloaded=1
		    echo "  Info: Downloaded successfully"
		else
		    echo "  Error: The checksums do not match - try next URL"
		fi	
	    else
		echo "  Warning: Failed to download file - try next URL"
	    fi
	done
	echo

        # Ups - no URL works
	if [ $downloaded != 1 ] ; then
	    echo "  Error: can download the file or checksum wrong (sha1sum ${DIST_CACHE_DIR}/${basename}  > ${basename}.sha1sum)"
	    exit 1;
	fi
	
    done
}

#####################
# Create files
####################
builder_create() {

    # converting icon file
    local iconfile_src=${DIST_FILE[$ICON_FILE_INDEX]}
    ICONFILE=$OUTPUT_DIR/$PN.png
    convert -colorspace rgb $iconfile_src -transparent white -background transparent -resize 160x160 \
	-size 160x160 xc:transparent +swap -gravity center -composite $ICONFILE
    builder_check_error "converting image"

}

#####################
# build opsi package
#####################
builder_package() {

    # prepare
    local inst_dir=$OUTPUT_DIR/$PN
    mkdir $inst_dir

    # Copy files and convert text files to dos format
    cp -Rv ${PRODUCT_DIR}/OPSI         $inst_dir
    cp -Rv ${PRODUCT_DIR}/CLIENT_DATA  $inst_dir
    find $inst_dir/CLIENT_DATA -type f | xargs -n1 -iREP sh -c 'file -i $0 | grep "text/plain" && dos2unix $0' REP
    
    # copy binaries
    for (( i = 0 ; i < ${#SOURCE[@]} ; i++ )) ; do
	distfile=${DIST_FILE[$i]}
	mkdir -p $inst_dir/CLIENT_DATA/${ARCH[$i]}
	cp ${DIST_FILE[$i]}   $inst_dir/CLIENT_DATA/${ARCH[$i]}
    done

    # create variables 
    local var_file=$OUTPUT_DIR/variable.ins
    echo -n >$var_file
    for (( i = 0 ; i < ${#SOURCE[@]} ; i++ )) ; do
	if [ -z ${WINST[$i]} ] ; then continue ; fi
	if [ ! -z "${ARCH[$i]}" ] ; then arch_str="${ARCH[$i]}\\" ; fi
	echo "DefVar \$${WINST[$i]}\$" >>$var_file
	echo "Set    \$${WINST[$i]}\$ = \"%ScriptPath%\\$arch_str${FILE[$i]}\""  >>$var_file
    done

    # publish some other variables
    for var in VENDOR PN VERSION RELEASE PRIORITY ADVICE TYPE CREATOR_TAG CREATOR_NAME CREATOR_EMAIL ; do 
        echo "DefVar \$${var}\$"            >>$var_file
        echo "Set    \$${var}\$ = \"${!var}\""  >>$var_file
    done

    # copy image and create variable
    cp -a $ICONFILE  $inst_dir/CLIENT_DATA
    echo "DefVar \$IconFile\$"  >>$var_file
    echo "Set    \$IconFile\$ = \"%ScriptPath%\\`basename $ICONFILE`\"" >>$var_file

    echo >>$var_file

    # add the new vaiables to all *.ins winst files 
    for inst_file in `find ${inst_dir}/CLIENT_DATA -type f -name "*.ins"` ; do
	sed -i -e "/@@BUILDER_VARIABLES@@/ { 
                    r "$var_file"
                    d 
                  }" $inst_file
    done

    # replace variables from OPSI control
    local release_new=${CREATOR_TAG}${RELEASE}
    sed -e "s!VERSION!$VERSION!g" -e "s!RELEASE!${release_new}!g" -e "s!PRIORITY!$PRIORITY!g" -e "s!ADVICE!$ADVICE!g" ${PRODUCT_DIR}/OPSI/control  >$inst_dir/OPSI/control
      
    # Create changelog based on git - if available
    if [ -d "${PRODUCT_DIR}/.git" ] ; then
	git log --date-order --date=short | \
	    sed -e '/^commit.*$/d' | \
	    awk '/^Author/ {sub(/\\$/,""); getline t; print $0 t; next}; 1' | \
	    sed -e 's/^Author: //g' | \
	    sed -e 's/>Date:   \([0-9]*-[0-9]*-[0-9]*\)/>\t\1/g' | \
	    sed -e 's/^\(.*\) \(\)\t\(.*\)/\3    \1    \2/g' > $inst_dir/OPSI/changelog.txt
    else
	echo "No git repository present."
    fi

    # Callback
    call_entry_point  result cb_package_makeproductfile

    # building package
    local opsi_file=${PN}_${VERSION}-${release_new}.opsi
    pushd ${OUTPUT_DIR}
    rm -f ${opsi_file} $OPSI_REPOS_FILE_PATTERN
    opsi-makeproductfile -v $inst_dir
    builder_check_error "Building OPSI-package"
    popd

    # rename opsi package file
    if [ "${opsi_file}" != "$OPSI_REPOS_FILE_PATTERN" ]; then
	mv ${OUTPUT_DIR}/${opsi_file} ${OUTPUT_DIR}/$OPSI_REPOS_FILE_PATTERN
	builder_check_error "can't move file  ${OUTPUT_DIR}/${opsi_file} ${OUTPUT_DIR}/$OPSI_REPOS_FILE_PATTERN"
    fi

}

#####################
# build opsi package
#####################
builder_publish() {

    # Upload file to repository
    mkdir -p ${OPSI_REPOS_PRODUCT_DIR}
    local src=$OUTPUT_DIR/${OPSI_REPOS_FILE_PATTERN}
    local dst=${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN}
    echo "Publishing opsi-package to $dst"
    cp  $src $dst
    builder_check_error "Can't upload file $dst --> $dst"

}

###################
# Commiting changes to repos
###################
builder_commit() {
    if [ -d "${PRODUCT_DIR}/.git" ]; then
	echo -n
	# echo "builder_commit() not implemented yet."
    fi
}


#####################
# build opsi package
#####################
builder_cleanup() {
    # Paranoia 
    if [ -d "$OUTPUT_DIR" ] && [[ $OUTPUT_DIR == $TMP_DIR/opsi-builder.* ]] ; then
	rm -rf $OUTPUT_DIR
    fi
}
