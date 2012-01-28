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
    
    # project dependent configuration
    local config=${PRODUCT_DIR}/builder-product.cfg
    test -f ${config} || builder_check_error "can't read product config: ${config}"
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
    eval "`grep -E "^STATUS=" $config`"

    # change some variable from the builder-product.cfg dynamically:
    # autogenerate release number, if we are in status "integration"
    if [ "$STATUS" = "integration" ] ; then
	# OPSI/control:RELEASE is limited to max 16 chars - take care in regards to the CREATOR_TAG
	RELEASE="`date +%Y%m%d%H%M`"
    fi

    # Read configurationfile
    . ${config}
    echo "Loaded builder configuration: $config"

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
    if  [ -z "$OPSI_REPOS_FORCE_UPLOAD" ] && [ -d ${OPSI_REPOS_PRODUCT_DIR} ]  ; then
	echo "Directory ${OPSI_REPOS_PRODUCT_DIR} already exists."
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

    # prepare
    INST_DIR=$OUTPUT_DIR/$PN
    mkdir $INST_DIR

    # Copy files and convert text files to dos format
    cp -Rv ${PRODUCT_DIR}/OPSI         $INST_DIR
    cp -Rv ${PRODUCT_DIR}/CLIENT_DATA  $INST_DIR
    find $INST_DIR/CLIENT_DATA -type f | xargs -n1 -iREP sh -c 'file -i $0 | grep "text/plain" && unix2dos $0' REP

    # converting icon file
    local iconfile_src=${DIST_FILE[$ICON_FILE_INDEX]}
    ICONFILE=$OUTPUT_DIR/$PN.png
    HIGHT=`identify -format "%h" $iconfile_src`
    WIGHT=`identify -format "%w" $iconfile_src`
    identify -format "%wx%h" $iconfile_src

    if [ $WIGHT -lt $HIGHT ]
    then
	# Its higher so force x160 and let imagemagic decide the right wight
	# then add transparency to the rest of the image to fit 160x160
	echo "Icon Wight: $WIGHT < Hight: $HIGHT"
	convert $iconfile_src -transparent white -background transparent -resize x160 \
	    -size 160x160 xc:transparent +swap -gravity center -composite $ICONFILE
	builder_check_error "converting image"
    elif [ $WIGHT -gt $HIGHT ]
    then
	# Its wider so force 160x and let imagemagic decide the right hight
	# then add transparency to the rest of the image to fit 160x160
	echo "Icon Wight: $WIGHT > Hight: $HIGHT"
	convert $iconfile_src -transparent white -background transparent -resize 160x \
	    -size 160x160 xc:transparent +swap -gravity center -composite $ICONFILE
	builder_check_error "converting image"
    elif [ $WIGHT -eq $HIGHT ]
    then
	# Its scare so force 160x160
	echo "Icon Wight: $WIGHT = Hight: $HIGHT"
	convert $iconfile_src -transparent white -background transparent -resize 160x160 \
	    -size 160x160 xc:transparent +swap -gravity center -composite $ICONFILE
	builder_check_error "converting image"
    else
	# Imagemagic is unable to detect the aspect ratio so just force 160x160
	# this could result in streched images
	#echo "Icon Wight: $WIGHT  Hight: $HIGHT"
	convert $iconfile_src -transparent white -background transparent -resize 160x160 \
	    xc:transparent +swap -gravity center -composite $ICONFILE
	builder_check_error "converting image"
    fi
    identify -format "%wx%h" $ICONFILE
    HIGHT=`identify -format "%h" $ICONFILE`
    WIGHT=`identify -format "%w" $ICONFILE`
    echo "Opsi Icon Wight: $WIGHT  Hight: $HIGHT"
    cp -a $ICONFILE  $INST_DIR/CLIENT_DATA

    
    # copy binaries
    for (( i = 0 ; i < ${#SOURCE[@]} ; i++ )) ; do
	distfile=${DIST_FILE[$i]}
	mkdir -p $INST_DIR/CLIENT_DATA/${ARCH[$i]}
	cp ${DIST_FILE[$i]}   $INST_DIR/CLIENT_DATA/${ARCH[$i]}
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
    echo "DefVar \$IconFile\$"  >>$var_file
    echo "Set    \$IconFile\$ = \"%ScriptPath%\\`basename $ICONFILE`\"" >>$var_file

    echo >>$var_file

    # add the new vaiables to all *.ins winst files 
    for inst_file in `find ${INST_DIR}/CLIENT_DATA -type f -name "*.ins"` ; do
	sed -i -e "/@@BUILDER_VARIABLES@@/ { 
                    r "$var_file"
                    d 
                  }" $inst_file
    done

    # replace variables from OPSI control
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

    # create source package
    zip -r ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.zip $INST_DIR


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
    cp  ${src}.opsi  ${dst}.opsi
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
