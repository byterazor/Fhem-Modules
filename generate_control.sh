#!/bin/bash
CONTROL_FILE="controls_byterazor-fhem-modules.txt"

if [ -e $CONTROL_FILE ]; then
  rm $CONTROL_FILE
fi

find ./FHEM -type f \( ! -iname "0.*" \) -print0 | while IFS= read -r -d '' f;
do
        out="UPD `stat --format "%z %s" $f | sed -e "s#\([0-9-]*\)\ \([0-9:]*\)\.[0-9]*\ [+0-9]*#\1_\2#"` $f"
        echo ${out//.\//} >> $CONTROL_FILE
done
