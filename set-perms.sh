#!/bin/bash
# This scipt sets super restrictive permissions on the automarker files.
# Read and execute bits are selectively set for others, on only the
# required public files.

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
THIS_SCRIPT=$(basename ${BASH_SOURCE[0]}) # Works w/ symbolic links
MARKER_SCRIPT=run-marker.sh
EXERCISER_SCRIPT=run-public-tests.sh
SUBMIT_SCRIPT=ece361submit.sh

cd ${SCRIPT_DIR} # In case this is executed from elsewhere

# Default: Remove rwx from everyone else
chmod -R og-rwx *

# Disable all write access on this and the marker script to prevent accidental modifications
chmod 500 ${THIS_SCRIPT} ${MARKER_SCRIPT}

# Enable public read and execute for exerciser and submit scripts
# Disable all writes to prevent accidental modifications
chmod 555 ${EXERCISER_SCRIPT} ${SUBMIT_SCRIPT}

# Set permissions for lab files and their cases
LAB_DIRS=`find . -type d -name "lab*"`
for DIR in ${LAB_DIRS}; do
    chmod 711 ${DIR}

    # Enable read and execute on all test scripts or binaries
    ALL_CASES=`cat ${DIR}/test-cases | grep -E "^(public|private)" | cut -d ' ' -f 2 | sort | uniq`
    for CASE in ${ALL_CASES}; do
        chmod 755 ${DIR}/${CASE}/pre-test ${DIR}/${CASE}/test ${DIR}/${CASE}/post-test ${DIR}/${CASE}/check-output
    done

    # Enable read and execute on public case directories
    PUBLIC_CASES=`cat ${DIR}/test-cases | grep "^public" | cut -d ' ' -f 2`
    for CASE in ${PUBLIC_CASES}; do
        chmod 711 ${DIR}/${CASE}
    done
    
    # Enable all others to read 'test-cases' and 'required-files' files
    chmod 644 ${DIR}/test-cases ${DIR}/required-files
done


# This directory only needs execute bit
chmod 711 ${SCRIPT_DIR}

cd -

