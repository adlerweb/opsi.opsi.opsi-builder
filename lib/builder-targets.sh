# Opsi Builder to automate the creation of Opsi packages for the Opsi Systen
#    Copyright (C) 2012  Daniel Schwager
#    Copyright (C) 2014  Mario Fetka
#    Copyright (C) 2018  Florian Knodt
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
  CMD_7z="`which 7z`"                 ; builder_check_error "Command '7z' not installed (apt install p7zip-full)"
  CMD_unzip="`which unzip`"           ; builder_check_error "Command 'unzip' not installed (apt install unzip)"
  CMD_unrar="`which unrar`"           ; builder_check_error "Command 'unrar' not installed (apt install unrar)"
  CMD_zip="`which zip`"               ; builder_check_error "Command 'zip' not installed (apt install zip)"
  CMD_tar="`which tar`"               ; builder_check_error "Command 'tar' not installed (apt install tar)"
  CMD_cabextract="`which cabextract`" ; builder_check_error "Command 'cabextract' not installed (apt install cabextract)"
  CMD_unix2dos="`which unix2dos`"     ; builder_check_error "Command 'unix2dos' not installed (apt install dos2unix)"
  CMD_identify="`which identify`"     ; builder_check_error "Command 'identify' not installed (apt install imagemagick)"
  CMD_zsyncmake="`which zsyncmake`"   ; builder_check_error "Command 'zsyncmake' not installed (apt install zsync)"
  CMD_comm="`which comm`"             ; builder_check_error "Command 'comm' not installed (apt install coreutils)"
  CMD_sha512sum="`which sha512sum`"   ; builder_check_error "Command 'sha512sum' not installed (apt install coreutils)"
  CMD_iniset="`which ini-set`"        ; builder_check_error "Command 'ini-set' not installed (apt install python-pip ; pip install martINI)"
  CMD_ruby="`which ruby`"             ; builder_check_error "Command 'ruby' not installed (apt install ruby)"
  CMD_gpg="`which gpg`"               ; builder_check_error "Command 'gpg' not installed  (apt install gpg)"

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
    if [ "${STATUS_INTEGRATION_RELEASE}" = "func:inc1" ] ; then
      . ${config}
      calc_release
    else
      # OPSI/control:RELEASE is limited to max 16 chars - take care in regards to the CREATOR_TAG
      RELEASE="${STATUS_INTEGRATION_RELEASE}"
    fi
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
  
  # Check, if variable is numeric
  if [ ! `expr ${OPSI_REPOS_PURGE_LIMIT} + 1 2> /dev/null` ]   ; then
    fatal_error "OPSI_REPOS_PURGE_LIMIT must be numeric"
  fi
  
}

#####################
# Prepare build
####################
builder_prepare() {
  echo "builder_prepare: "
  # Check if the package is still build
  if  [  "$OPSI_REPOS_FORCE_UPLOAD" != "true" ] && [ -f "${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi" ]  ; then
    echo "File ${OPSI_REPOS_PRODUCT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi already exists."
    exit 1
  fi
  
  mkdir -p $DIST_CACHE_DIR
  log_debug "Distribution directory: $DIST_CACHE_DIR"
  
  # setup work directory
  OUTPUT_DIR="$TMP_DIR/opsi-builder.`date +%Y%m%d-%H%M%S`.$$"
  mkdir -p ${OUTPUT_DIR}
  builder_check_error "Cannot create temp directory ${OUTPUT_DIR}"
  
  # prepare
  INST_DIR=$OUTPUT_DIR/$PN
  mkdir $INST_DIR
  
  log_info "  OUTPUT_DIR: $OUTPUT_DIR"
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
    if [ ! -z ${DIST_PRIVATE_REPOS} ] && [ -d "${DIST_PRIVATE_REPOS}" ]; then
      urls="${DIST_PRIVATE_REPOS}/$basename;$urls"
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
      retrieve_file $downloader $src ${DL_DIST_FILE[$i]}
      
      if [ $? != 0 ] ; then
        echo "  Warning: Failed to download file - try next URL"
        continue;
      fi
      
      # Check sha512
      local checksum_val=$($CMD_sha512sum ${DL_DIST_FILE[$i]} | cut -d " " -f1)
      if [ -z ${DL_SHA512[$i]+x} ] ; then
        downloaded=1
        echo "  WARNING: SHA512 checksum missing. ${checksum_val}"
      else
        if [ "$checksum_val" = "${DL_SHA512[$i]}" ] ; then
          downloaded=1
        fi
      fi
      
      # Print result
      if [ "$downloaded" == "1" ] ; then
        echo "  Info: Downloaded successfully"
      else
        echo "  Error: The checksums do not match - try next URL"
        echo "     DL:  ${checksum_val}"
        echo "     SET: ${DL_SHA512[$i]}"
      fi
      
    done
    echo
    
    # Ups - no URL works
    if [ $downloaded != 1 ] ; then
      echo "  Error: can download the file or checksum wrong"
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
  if [ -d "${PRODUCT_DIR}/CLIENT_DATA" ] ; then
    cp -Rv ${PRODUCT_DIR}/CLIENT_DATA  $INST_DIR
  fi
  if [ -d "${PRODUCT_DIR}/SERVER_DATA" ] ; then
    cp -Rv ${PRODUCT_DIR}/SERVER_DATA  $INST_DIR
  fi
  
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
    local option=${DL_EXTRACT_OPTION[$i]}
    if [ -z "$option" ] ; then option=""; fi
    
    mkdir -p ${DL_EXTRACT_PATH[$i]}
    process_file $format ${DL_DIST_FILE[$i]} ${DL_EXTRACT_PATH[$i]} $option
  done
  
  # create winst variables
  local var_file=${OUTPUT_DIR}/variable.ins
  create_winst_varfile  $var_file
  
  # write ini file
  local ini_file=${INST_DIR}/CLIENT_DATA/opsi-$PN.ini
  write_ini_file  $ini_file $var_file
  
  echo ";Hardcoded opsi vars" >>$var_file
  echo "Set    \$ProductId\$ = \"$PN\""  >>$var_file
  
  # add the new vaiables to all *.ins winst files
  for inst_file in `find ${INST_DIR}/CLIENT_DATA -type f -name "*.ins"` ; do
    sed -i -e "/@@BUILDER_VARIABLES@@/ {
                    r "$var_file"
                    d
    }" $inst_file
  done

  # convert to dos file linefeed
  find $INST_DIR/CLIENT_DATA -type f | xargs -n1 -iREP sh -c 'file -i $0 | grep -v "utf-16" | grep "text/plain" && '$CMD_unix2dos' $0 ' REP >/dev/null

  # set exec bit on executeables
  find $INST_DIR/CLIENT_DATA -type f -iname "*.exe" -o -iname "*.bat" -o -iname "*.cmd" -o -iname "*.msi" -o -iname "*.msp" | xargs chmod +x -v

  # replace variables from file OPSI/control
  local release_new=${CREATOR_TAG}${RELEASE}
  write_control_file $INST_DIR/OPSI/control "Package" "version" "${release_new}"
  write_control_file $INST_DIR/OPSI/control "Product" "id" "$PN"
  write_control_file $INST_DIR/OPSI/control "Product" "name" "$NAME"
  write_control_file $INST_DIR/OPSI/control "Product" "description" "$DESCRIPTION"
  write_control_file $INST_DIR/OPSI/control "Product" "advice" "$ADVICE"
  write_control_file $INST_DIR/OPSI/control "Product" "version" "$VERSION"
  write_control_file $INST_DIR/OPSI/control "Product" "priority" "$PRIORITY"
  
  # Create changelog based on git - if available
  if [ -d "${PRODUCT_DIR}/.git" ] ; then
    # new changelog format
    echo "" >> $INST_DIR/OPSI/control
    echo "[Changelog]" >> $INST_DIR/OPSI/control
    $CMD_ruby $BASEDIR/libexec/gitlog-to-deblog.rb >> $INST_DIR/OPSI/control
    echo "" >> $INST_DIR/OPSI/control
    rm -f $INST_DIR/OPSI/changelog.txt
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
  LANG="C" PYTHONIOENCODING='utf-8' opsi-makepackage -v $INST_DIR
  builder_check_error "Building OPSI-package"
  popd
  
  # rename opsi package file
  if [ "${opsi_file}" != "${OPSI_REPOS_FILE_PATTERN}.opsi" ]; then
    mv ${OUTPUT_DIR}/${opsi_file} ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi
    builder_check_error "can't move file  ${OUTPUT_DIR}/${opsi_file} ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.opsi"
  fi
  
  # --exclude \*/.git\*
  # create source- and binary package package
  test "${OPSI_REPOS_UPLOAD_BIN}" = "true"    && $CMD_zip --exclude \*/.git\* @ -r ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}.zip $INST_DIR
  test "${OPSI_REPOS_UPLOAD_SOURCE}" = "true" && $CMD_zip --exclude \*/.git\* @ -r ${OUTPUT_DIR}/${OPSI_REPOS_FILE_PATTERN}-src.zip ${PRODUCT_DIR}
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
  
  # Link dir
  if [ "${OPSI_REPOS_LINK_NEWBUILDS}" = "true" ] ; then
    mkdir -p ${OPSI_REPOS_BASE_DIR}/.new_builds
    ln -sf ${OPSI_REPOS_PRODUCT_DIR}  ${OPSI_REPOS_BASE_DIR}/.new_builds/${OPSI_REPOS_FILE_PATTERN}
    builder_check_error "Can't Link file $dst.opsi --> $dst.opsi"
  fi
  
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
  
  if [ "${OPSI_REPOS_OPSIMANAGER_INSTALL}" = "true" ] ; then
    opsi-package-manager -i -v ${src}.opsi
    builder_check_error "Can't install ${src}.opsi"
  fi
  
  if [ "${OPSI_REPOS_UPLOAD_OPSI_ZSYNC}" = "true" ] ; then
    md5sum "${src}.opsi" | sed 's/ .*//' > ${dst}.opsi.md5
    builder_check_error "Can't create md5 file"
    
    ${CMD_zsyncmake} -u ${OPSI_REPOS_FILE_PATTERN}.opsi -o "${dst}.opsi.zsync" "${src}.opsi"
    builder_check_error "Can't create zsync file"
  fi

  if [ "${OPSI_REPOS_UPLOAD_OPSI_GPG}" = "true" ] ; then
    ${CMD_gpg} --batch --passphrase ${GPG_PASSPHRASE} --output "${dst}.opsi.gpg" --detach-sig "${src}.opsi"
    builder_check_error "Can't create gpg file"
  fi

  # Create revision file for this
  local rev_file=${OPSI_REPOS_PRODUCT_DIR}/${PN}-${VERSION}-${CREATOR_TAG}${RELEASE}.cfg
    cat > $rev_file <<EOF
REV_VENDOR=${VENDOR}
REV_PN=${PN}
REV_NAME="${NAME}"
REV_VERSION=${VERSION}
REV_RELEASE=${RELEASE}
REV_TYPE=${TYPE}
REV_STATUS=${STATUS}
REV_TIMESTAMP=`date +"%s"`
REV_CREATOR_TAG=${CREATOR_TAG}
REV_OPSI_REPOS_FILE_PATTERN=${OPSI_REPOS_FILE_PATTERN}
EOF
  
  
  # Purge old product versions - defined by limit OPSI_REPOS_PURGE_LIMIT
  if [ "${OPSI_REPOS_PURGE}" = "true" ]  && [ ! -z "${OPSI_REPOS_PURGE_LIMIT}" ]  && [ "${OPSI_REPOS_PURGE_LIMIT}" > 0 ] && [ "${STATUS}" = "${OPSI_REPOS_PURGE_STATUS}" ] ; then
    echo "Autopurging enabled"
    
    # determinte max version to delete
    local limit
    local pn_limit=`echo ${PN} | sed "s/[\.\-]/_/g"`
    eval "`echo limit=\\$\\{OPSI_REPOS_PURGE_LIMIT_${pn_limit}\\}`"
    if [ -z "$limit" ] || [ ! `expr $limit + 1 2>/dev/null` ]  ; then
      limit=${OPSI_REPOS_PURGE_LIMIT}
    fi
    echo "  Purging, max. number of versions: $limit"
    
    # Find all revision files and sort them
    local file_list=${OUTPUT_DIR}/product-file-list.txt
    local file_sort_list=${OUTPUT_DIR}/product-file-sort-list.txt
    local file_sort_list_version=${OUTPUT_DIR}/product-file-sort-list-version.txt
    local file_sort_list_release=${OUTPUT_DIR}/product-file-sort-list-release.txt
    local file_sort_list_final=${OUTPUT_DIR}/product-file-sort-list-final.txt
    rm -f ${file_list}
    
    # first uniq sort all cfg based on version
    for cfg_file in `find ${OPSI_REPOS_PRODUCT_DIR} -name "${PN}-*.cfg" -print ` ; do
      . ${cfg_file}
      echo $REV_VERSION >> ${file_list}
    done
    sort -V ${file_list} | uniq > ${file_sort_list_version}
    
    # second uniq sort all versions based in release
    for pkg_version in `cat ${file_sort_list_version}` ; do
      for cfg_file_ver in ${OPSI_REPOS_PRODUCT_DIR}/${PN}-${pkg_version}-*.cfg ; do
        . ${cfg_file_ver}
        echo ${pkg_version}-$REV_CREATOR_TAG$REV_RELEASE >> ${file_sort_list_release}
      done
    done
    sort -V ${file_sort_list_release} | uniq > ${file_sort_list_final}
    
    # third create versionrelease
    for release_file_list in `cat ${file_sort_list_final}` ; do
      . ${OPSI_REPOS_PRODUCT_DIR}/${PN}-${release_file_list}.cfg
      echo "${OPSI_REPOS_PRODUCT_DIR}/${PN}-${release_file_list}.cfg" >> ${file_sort_list}
    done
    
    # Delete the oldest files
    log_debug "base list for calculate purge:"
    for cfg_sort_file in `head -n-${limit} ${file_sort_list}` ; do
      
      . ${cfg_sort_file}
      if [ "${REV_STATUS}" != "${OPSI_REPOS_PURGE_STATUS}" ] ; then continue; fi
      
      dir_base=`dirname ${cfg_file}`
      product_file="${dir_base}/${REV_OPSI_REPOS_FILE_PATTERN}"
      echo "  Purging product version: $product_file*"
      
      # Paranoid ... check the files to delete first
      if [ ! -z "${dir_base}" ] && [ -d "${OPSI_REPOS_BASE_DIR}" ] && [ ! -z "$product_file" ] ; then
        rm -f ${product_file}* ${cfg_sort_file}
        
        # remove directory - if it's empty
        if [ $(ls -1A ${dir_base} | wc -l) -eq 0 ]; then
          rmdir ${dir_base}
        fi
      fi
    done
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
