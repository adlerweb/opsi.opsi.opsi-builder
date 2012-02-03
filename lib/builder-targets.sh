#####################
# Call user entry point
####################

# source generic utility functions
. $BASEDIR/lib/builder-utils.sh

#####################
# Read config
####################
builder_config() {

    # Define commands
    CMD_7z="`which 7z`"       ; builder_check_error "No 7z installed"
    CMD_unzip="`which unzip`"  ; builder_check_error "No unzip installed"
    CMD_zip="`which zip`"      ; builder_check_error "No zip installed"


    # Check temp dir
    test -d ${TMP_DIR}
    builder_check_error "temp directory not available: $TMP_DIR"
    
    # project dependent configuration
    local config=${PRODUCT_DIR}/builder-product.cfg
    test -f ${config} || builder_check_error "cannot read product config: ${config}"
    . ${config} 
    
    # set default build configuration and source the user dependent file
    local config=$BASEDIR/conf/opsi-builder.cfg
    . ${config}

    #  Source local build configuration (must be done AFTER sourcing the builder-product.cfg.cfg)
    if [ -f "$OPSI_BUILDER" ] ; then
	config=$OPSI_BUILDER
    else	
	test -f $HOME/.opsi-builder.cfg && config=$HOME/.opsi-builder.cfg
    fi

    # Read ONLY the STATUS variable from the build configuration file
    eval "`grep -E "^(STATUS|STATUS_INTEGRATION_RELEASE)=" $config`"

    # change some variable from the builder-product.cfg dynamically:
    # autogenerate release number, if we are in status "integration"
    if [ "$STATUS" = "integration" ] ; then
	# OPSI/control:RELEASE is limited to max 16 chars - take care in regards to the CREATOR_TAG
	RELEASE="${STATUS_INTEGRATION_RELEASE}"
    fi

    # Read configurationfile
    . ${config}
    echo "Loaded builder configuration: $config"

    # Check variables
    if [ -z ${OPSI_REPOS_BASE_DIR} ] || [ ! -d ${OPSI_REPOS_BASE_DIR} ] ; then
	echo "configuration error: OPSI_REPOS_BASE_DIR directory does not exist: $OPSI_REPOS_BASE_DIR"
	exit 2
    fi

    if [  "$TYPE" != "public" ] && [  "$TYPE" != "restricted" ]  ; then
	fatal_error "unknown TYPE: $TYPE"
    fi

}

#####################
# Prepare build
####################
builder_prepare() {

    # Check if the package is still build
    if  [ -z "$OPSI_REPOS_FORCE_UPLOAD" ] && [ -f "${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi" ]  ; then
	echo "Directory ${OPSI_REPOS_PRODUCT_DIR} already exists."
	exit 1
    fi

    mkdir -p $DIST_CACHE_DIR
    echo "Distribution directory: $DIST_CACHE_DIR"

    # setup work directory
    OUTPUT_DIR=$(mktemp -d $TMP_DIR/opsi-builder.XXXXXXXXXX) || { echo "Failed to create temp dir"; exit 1; }

    # prepare
    INST_DIR=$OUTPUT_DIR/$PN
    mkdir $INST_DIR

}


#####################
# Download all dist files from one of the defined URLs. 
# and validate the checksum
####################
builder_retrieve() {

    for (( i = 0 ; i < ${#DL_SOURCE[@]} ; i++ )) ; do
	local basename=${DL_FILE[$i]}
	local urls=${DL_SOURCE[$i]}
	local arch=${DL_ARCH[$i]}
	local downloaded=0

	# Add private repos to the urls
	if [ ! -z ${DIST_PRIVATE_REPOS} ]; then
	    urls="${DIST_PRIVATE_REPOS}/$basename;$urls"
	fi
	
	# check existence of CRC file only in non devel mode
	if [ ! -e "${PRODUCT_DIR}/${basename}.sha1sum" ] && [ "$CHECKSUM_AUTOCREATE" != "true" ] ; then
	    fatal_error "You need to create the checksums with: sha1sum ${DIST_CACHE_DIR}/${basename}  > ${PRODUCT_DIR}/${basename}.sha1sum"
	fi

	echo "Downloading $basename"
	# check downloading from the defined URLs
	for src in `echo  $urls | sed -e 's/[;,]/\n/g'`  ; do
	    if [ $downloaded == 1 ]; then continue; fi

	    # Download file
	    echo "  Info: Downloding from $src"
	    local downloader=${DL_DOWNLOADER[$i]}
	    if [ -z $downloader ]; then downloader="wget" ; fi

	    mkdir -p ${DIST_CACHE_DIR}/$arch
	    DL_DIST_FILE[$i]=${DIST_CACHE_DIR}/$arch/$basename
	    retrieve_file $downloader $src  ${DL_DIST_FILE[$i]}

	    if [ $? != 0 ] ; then 
		echo "  Warning: Failed to download file - try next URL"
		continue;
	    fi

	    # Check sha1
	    if  [ ! -e "${PRODUCT_DIR}/${basename}.sha1sum" ] && [ "$CHECKSUM_AUTOCREATE" == "true" ] ; then
		sha1sum ${DL_DIST_FILE[$i]}  > ${PRODUCT_DIR}/${basename}.sha1sum
		downloaded=1
		echo "  WARNING: SHA1 checksum (${DL_DIST_FILE[$i]}.sha1sum) was created dynamically because auf CHECKSUM_AUTOCREATE=$CHECKSUM_AUTOCREATE"
	    else
	        # testing the checksum of the downloaded files
		local sha1sum_val=`cat ${PRODUCT_DIR}/${basename}.sha1sum | cut -d " " -f1`
		local checksum_val=`sha1sum ${DL_DIST_FILE[$i]} | cut -d " " -f1`
		if [ "$checksum_val" == "$sha1sum_val" ] ; then 
		    downloaded=1
		fi	
	    fi
	    
	    # Print result
	    if [ "$downloaded" == "1" ] ; then 
		echo "  Info: Downloaded successfully"
	    else
		echo "  Error: The checksums do not match - try next URL"
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

    # Copy files and convert text files to dos format
    cp -Rv ${PRODUCT_DIR}/OPSI         $INST_DIR
    cp -Rv ${PRODUCT_DIR}/CLIENT_DATA  $INST_DIR
    find $INST_DIR/CLIENT_DATA -type f | xargs -n1 -iREP sh -c 'file -i $0 | grep "text/plain" && unix2dos $0 ' REP >/dev/null

    # converting icon file
    local iconfile_src=${DL_DIST_FILE[$ICON_DL_INDEX]}
    ICONFILE=$OUTPUT_DIR/$PN.png
    convert_image $iconfile_src $ICONFILE
    cp -a $ICONFILE  $INST_DIR/CLIENT_DATA
    
    # copy binaries
    for (( i = 0 ; i < ${#DL_SOURCE[@]} ; i++ )) ; do
	DL_EXTRACT_PATH[$i]=${INST_DIR}/CLIENT_DATA/${DL_ARCH[$i]}/${DL_EXTRACT_TO[$i]}
	local format=${DL_EXTRACT_FORMAT[$i]}
	if [ -z "$format" ] ; then format="cp"; fi

	mkdir -p ${DL_EXTRACT_PATH[$i]}
	process_file $format ${DL_DIST_FILE[$i]} ${DL_EXTRACT_PATH[$i]}
    done

    # create winst variables 
    local var_file=${OUTPUT_DIR}/variable.ins
    create_winst_varfile  $var_file

    # add the new vaiables to all *.ins winst files 
    for inst_file in `find ${INST_DIR}/CLIENT_DATA -type f -name "*.ins"` ; do
	sed -i -e "/@@BUILDER_VARIABLES@@/ { 
                    r "$var_file"
                    d 
                  }" $inst_file
    done

    # replace variables from file OPSI/control
    local release_new=${CREATOR_TAG}${RELEASE}
    sed -e "s!VERSION!$VERSION!g" -e "s!RELEASE!${release_new}!g" -e "s!PRIORITY!$PRIORITY!g" -e "s!ADVICE!$ADVICE!g" ${PRODUCT_DIR}/OPSI/control  >$INST_DIR/OPSI/control
      
    # Create changelog based on git - if available
    if [ -d "${PRODUCT_DIR}/.git" ] ; then
	git log --date-order --date=short | \
	    sed -e '/^commit.*$/d' | \
	    awk '/^Author/ {sub(/\\$/,""); getline t; print $0 t; next}; 1' | \
	    sed -e 's/^Author: //g' | \
	    sed -e 's/>Date:   \([0-9]*-[0-9]*-[0-9]*\)/>\t\1/g' | \
	    sed -e 's/^\(.*\) \(\)\t\(.*\)/\3    \1    \2/g' > $INST_DIR/OPSI/changelog.txt
    else
	echo "No git repository present."
    fi

}

#####################
# build opsi package
#####################
builder_package() {

    # creating package
    local release_new=${CREATOR_TAG}${RELEASE}
    local opsi_file=${PN}_${VERSION}-${release_new}.opsi

    pushd ${OUTPUT_DIR}
    rm -f ${opsi_file} ${OPSI_REPOS_FILE_PATTERN}.opsi
    LANG="C" opsi-makeproductfile -v $INST_DIR
    builder_check_error "Building OPSI-package"
    popd

    # rename opsi package file
    if [ "${opsi_file}" != "${OPSI_REPOS_FILE_PATTERN}.opsi" ]; then
	mv ${OUTPUT_DIR}/${opsi_file} ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi
	builder_check_error "can't move file  ${OUTPUT_DIR}/${opsi_file} ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi"
    fi

    # create source- and binary package package
    test "${OPSI_REPOS_UPLOAD_BIN}" = "true"    && $CMD_zip -r ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.zip $INST_DIR
    test "${OPSI_REPOS_UPLOAD_SOURCE}" = "true" && $CMD_zip -r ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}-src.zip ${PRODUCT_DIR} 
}


#####################
# publish
#####################
builder_publish() {

    # Upload file to repository
    mkdir -p ${OPSI_REPOS_PRODUCT_DIR}

    echo "Publishing opsi-package to ${OPSI_REPOS_PRODUCT_DIR}"
    local src=${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}
    local dst=${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN}

    # copy files
    if [ "${OPSI_REPOS_UPLOAD_OPSI}" = "true" ] ; then
	cp  ${src}.opsi  ${dst}.opsi
	builder_check_error "Can't upload file $dst.opsi --> $dst.opsi"
    fi

    if [ "${OPSI_REPOS_UPLOAD_BIN}" = "true" ] ; then
	cp  ${src}.zip   ${dst}.zip
	builder_check_error "Can't upload file $dst.zip --> $dst.zip"
    fi

    if [ "${OPSI_REPOS_UPLOAD_SOURCE}" = "true" ] ; then
	cp  ${src}-src.zip   ${dst}-src.zip
	builder_check_error "Can't upload file ${dst}-src.zip --> ${dst}-src.zip"
    fi

    if [ "${OPSI_REPOS_UPLOAD_OPSI_ZSYNC}" = "true" ] ; then 
	md5sum "${dst}.opsi" | sed 's/ .*//' > ${dst}.opsi.md5
	builder_check_error "Can't create md5 file"
	
	zsyncmake -u ${OPSI_REPOS_FILE_PATTERN}.opsi -o "${dst}.opsi.zsync" "${dst}.opsi"
	builder_check_error "Can't create zsync file"
    fi



}

###################
# Commiting changes to repos
###################
builder_commit() {
    if [ -d "${PRODUCT_DIR}/.git" ]; then
	echo -n
	log_debug "builder_commit() not implemented yet."
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
