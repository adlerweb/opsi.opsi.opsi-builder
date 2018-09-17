# Opsi Builder to automate the creation of Opsi packages for the Opsi Systen
#    Copyright (C) 2012  Daniel Schwager
#    Copyright (C) 2014  Mario Fetka
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
  local option=$4
  
  # Check, if the URL is a file URL starting with file://
  if [ -f $dst ] && [ -z ${DIST_FORCE_DOWNLOAD} ]; then
    echo "  Info: File still cached/downloaded. To force a download, set DIST_FORCE_DOWNLOAD=1"
    elif [[ $src == file://* ]]; then
    fileurl=`echo $src | sed "s/^file:\/\///"`
    cp  $fileurl $dst  2>/dev/null
  else
    rm -f $dst
    if [ "$downloader" = "wget" ]; then
      wget --header='Cookie: oraclelicense=accept-securebackup-cookie' --tries=1 -O $dst --timeout=5 -q --no-verbose "$src"
      if [ "$?" == "1" ] ; then
        rm $dst
      fi
      elif [ "$downloader" = "plowdown" ]; then
      plowdown --max-retries=1 -o ${dst%/*} "$src"
      elif [ "$downloader" = "aria2c" ]; then
      #aria2c --seed-time=0 -d ${dst%/*} -o ${dst##*/} "$src"
      aria2c --seed-time=0 --allow-overwrite=true -o ${dst##*/} "$src"
      mv -f ${dst##*/} ${dst%/*}
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
  local option=$4
  
  log_debug "Compression format: $format"
  
  if [ "$format" = "cp" ]; then
    cp $src $dst
    elif [ "$format" = "7zip" ]; then
    $CMD_7z x -y $option -o$dst $src
    elif [ "$format" = "unzip" ]; then
    $CMD_unzip $option -o $src -d $dst
    elif [ "$format" = "unrar" ]; then
    $CMD_unrar x -y $option $src $dst
    elif [ "$format" = "lha" ]; then
    $CMD_lha x $option -w=$dst $src
    elif [ "$format" = "targz" ]; then
    $CMD_tar xzvf $option $src -C $dst
    elif [ "$format" = "tarbz2" ]; then
    $CMD_tar xjvf $option $src -C $dst
    elif [ "$format" = "cab" ]; then
    $CMD_cabextract $option -d $dst $src
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
  exit 1
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
  
  local hight=`${CMD_identify} -format "%h" $src`
  local wight=`${CMD_identify} -format "%w" $src`
  ${CMD_identify} -format "%wx%h" $src
  
  # Add a white border to the image so that the convert to transparent can go around an image
  convert -bordercolor White -border 3x3 $src $OUTPUT_DIR/bigger.png
  
  # first resize the image to the new aspect ratio and add white borders
  if [ $wight -lt $hight ] ; then
    # Its higher so force x166 and let imagemagic decide the right wight
    # then add white to the rest of the image to fit 166x166
    log_debug "Icon Wight: $wight < Hight: $hight"
    convert $OUTPUT_DIR/bigger.png -colorspace RGB -resize x166 \
    -size 166x166 xc:white +swap -gravity center  -composite \
    -modulate 110 -colors 256 png8:$OUTPUT_DIR/resize.png
    builder_check_error "converting image"
    elif [ $wight -gt $hight ] ; then
    # Its wider so force 166x and let imagemagic decide the right hight
    # then add white to the rest of the image to fit 166x166
    log_debug "Icon Wight: $wight > Hight: $hight"
    convert $OUTPUT_DIR/bigger.png -colorspace RGB -resize 166x \
    -size 166x166 xc:white +swap -gravity center  -composite \
    -modulate 110 -colors 256 png8:$OUTPUT_DIR/resize.png
    builder_check_error "converting image"
    elif [ $wight -eq $hight ] ; then
    # Its scare so force 166x166
    log_debug "Icon Wight: $wight = Hight: $hight"
    convert $OUTPUT_DIR/bigger.png -colorspace RGB -resize 166x166 \
    -size 166x166 xc:white +swap -gravity center  -composite \
    -modulate 110 -colors 256 png8:$OUTPUT_DIR/resize.png
    builder_check_error "converting image"
  else
    # Imagemagic is unable to detect the aspect ratio so just force 166x166
    # this could result in streched images
    log_debug "Icon Wight: $wight unknown Hight: $hight"
    convert $OUTPUT_DIR/bigger.png -colorspace RGB -resize 166x166 \
    -size 166x166 xc:white +swap -gravity center  -composite \
    -modulate 110 -colors 256 png8:$OUTPUT_DIR/resize.png
    builder_check_error "converting image"
  fi
  
  # create a diffence image from the source
  convert $OUTPUT_DIR/resize.png \( +clone -fx 'p{0,0}' \)  -compose Difference  -composite \
  -modulate 100,0  +matte $OUTPUT_DIR/difference.png
  
  # remove the black, replace with transparency
  convert $OUTPUT_DIR/difference.png -bordercolor white -border 1x1 -matte \
  -fill none -fuzz 7% -draw 'matte 1,1 floodfill' -shave 1x1 \
  $OUTPUT_DIR/removed_black.png
  
  # create the matte
  if [ `convert | grep Version | awk '{print $3}' | sed "s/-.*//" | sed "s/\.//g"` -le 670 ] ; then
    convert $OUTPUT_DIR/removed_black.png -channel matte -separate +matte \
    $OUTPUT_DIR/matte.png
  else
    convert $OUTPUT_DIR/removed_black.png -channel matte -negate -separate +matte \
    $OUTPUT_DIR/matte.png
  fi
  
  # negate the colors
  convert $OUTPUT_DIR/matte.png -negate -blur 0x1 \
  $OUTPUT_DIR/matte-negated.png
  
  # you are going for: white interior, black exterior
  composite -compose CopyOpacity $OUTPUT_DIR/matte-negated.png $OUTPUT_DIR/resize.png \
  $OUTPUT_DIR/smaller.png
  
  # now remove the added border that was added eaerlier
  # Chop 3 pixels from the top and left side of
  convert -chop 3x3 -rotate 180 $OUTPUT_DIR/smaller.png $OUTPUT_DIR/rotate.png
  
  # Chop 3 pixels from the bottom and right side
  convert -chop 3x3 -rotate 180 $OUTPUT_DIR/rotate.png $dst
  
  # New size
  # identify -format "%wx%h" $dst
  hight=`${CMD_identify} -format "%h" $dst`
  wight=`${CMD_identify} -format "%w" $dst`
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
  echo "; Opsi Builder Variables" >>$var_file
  
  # make the scriptpath for the binarys configurable
  echo "DefVar \$PackagePath\$" >>$var_file
  echo "Set    \$PackagePath\$ = \"%ScriptPath%\""  >>$var_file
  
  echo >>$var_file
  for (( i = 0 ; i < ${#DL_SOURCE[@]} ; i++ )) ; do
    if [ -z ${DL_WINST_NAME[$i]} ] ; then continue ; fi
    
    if [ ! -z "${DL_ARCH[$i]}" ] ; then arch_str="${DL_ARCH[$i]}\\" ; fi
    echo "DefVar \$${DL_WINST_NAME[$i]}\$" >>$var_file
    echo "Set    \$${DL_WINST_NAME[$i]}\$ = \$PackagePath\$ + \"\\${arch_str}${DL_FILE[$i]}\""  >>$var_file
  done
  
  # publish some other variables
  for var in VENDOR PN VERSION RELEASE PRIORITY NAME ADVICE TYPE CREATOR_TAG CREATOR_NAME CREATOR_EMAIL ; do
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
      local new_val="\$PackagePath\$ + $arch_part$extr_part"
      WINST_VALUE[$i]=`echo ${WINST_VALUE[$i]} | sed -e "s#@DL_EXTRACT_WINST_PATH\[[0-9]\]@#$new_val#"`
      log_debug "calculated (DL_EXTRACT_WINST_PATH) WINST_VALUE: ${WINST_VALUE[$i]}"
    fi
    
    echo "DefVar \$${WINST_NAME[$i]}\$" >>$var_file
    echo "Set    \$${WINST_NAME[$i]}\$ = \"${WINST_VALUE[$i]}\""  >>$var_file
  done
  
  # correct me im a hack
  sed -e 's#"\$PackagePath\$ +#\$PackagePath\$ + "#' -i $var_file
  sed -e 's#\$PackagePath\$ + " #\$PackagePath\$ + "#' -i $var_file
  echo >>$var_file
}

#####################
# void calc_release()
#
# Description:
#   Calculate new release based on
#   the latest one found in the repository.
#
# $RELEASE is set to the calculated release.
#
####################
function calc_release() {
  
  # Find all revision files and sort them
  local file_list=`mktemp /tmp/opsi-builder.calc_release.XXXXXXXXXXX`
  for cfg_file in `find ${OPSI_REPOS_BASE_DIR} -name "${PN}-${VERSION}-${CREATOR_TAG}*.cfg" -print ` ; do
    . ${cfg_file}
    printf "%08d;$cfg_file\n" $REV_RELEASE >> ${file_list}
  done
  local oldest_cfg=`sort -n ${file_list} | cut -f 2 -d ";" | tail -1`
  rm -f ${file_list}
  
  if [ ! -f "${oldest_cfg}" ] ; then
    echo "Warning: no cfg-file found for this product. RELEASE will be set to 1"
    RELEASE=1
  else
    log_debug "calc_release() oldest_cfg: ${oldest_cfg}"
    . ${oldest_cfg}
    log_debug "  latest release: $REV_RELEASE"
    RELEASE=`expr ${REV_RELEASE} + 1 2> /dev/null`
    builder_check_error "Cannot incrememnt REV_RELEASE from file ${oldest_cfg}"
  fi
}

###################
# Write Package Ini file
#
# Create a ini file containing needed information for package uninstall
#
# Parameter
#  file: file to create / modify
#
###################
write_ini_file() {
  local ini_file=$1
  local var_file=$2
  
  # create file if not exist
  touch $ini_file
  
  # publish some other variables
  for var in VENDOR PN VERSION RELEASE TYPE CREATOR_TAG CREATOR_NAME CREATOR_EMAIL ; do
    $CMD_iniset $ini_file --COMMON ${var}="${!var}"
  done
  
  echo "; Opsi INI File Variables" >>$var_file
  echo >>$var_file
  # publish custom variables
  for (( i = 0 ; i < ${#OPSI_INI_OPTION[@]} ; i++ )) ; do
    $CMD_iniset $ini_file --${OPSI_INI_SECTION[$i]} ${OPSI_INI_OPTION[$i]}="${OPSI_INI_VALUE[$i]}"
    echo "DefVar \$${OPSI_INI_OPTION[$i]}\$" >>$var_file
    echo "Set    \$${OPSI_INI_OPTION[$i]}\$ = \"${OPSI_INI_VALUE[$i]}\""  >>$var_file
  done
  
  echo >>$var_file
}

###################
# Write control file
#
# Create a ini file containing needed information for package uninstall
#
# Parameter
#  file: file to create / modify
#
###################
write_control_file() {
  local control_file=$1
  local control_section=$2
  local control_option=$3
  local control_value=$4
  
  sed -i -e "/^\[$control_section\]/,/^\[.*\]/ s|^\($control_option[ \t]*:[ \t]*\).*$|\1$control_value|" "$control_file"
}

