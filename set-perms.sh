#!/bin/bash
# This scipt sets super restrictive permissions on the automarker files.
# Read and execute bits are selectively set for others, on only the
# required public files.
#
# NOTE: Some leniency given to group members (TAs may need to debug), so we
# currently enable write access to some key files. As this system starts
# to mature, it may be possible to remove write access and let only the head
# TA handle this system.
#   TODO: Periodic review at end of each term to see if any changes were
#         required in the past semester. If things seem stable, make this
#         more restrictive.
#

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
THIS_SCRIPT=$(basename ${BASH_SOURCE[0]}) # Works w/ symbolic links
MARKER_SCRIPT=run-marker.sh
EXERCISER_SCRIPT=run-public-tests.sh
SUBMIT_SCRIPT=ece361submit.sh
MOSS_SCRIPT=run-moss.sh
DUE_DATES_FILE=lab-due-dates
CLOSE_LABS_SCRIPT=set-close-labs.sh

cd ${SCRIPT_DIR} # In case this is executed from elsewhere

# Default: Remove rwx from others
chmod -R o-rwx *

# Disable all write access on this and TA-only scripts to prevent accidental modifications
chmod 550 ${THIS_SCRIPT} ${MARKER_SCRIPT} ${MOSS_SCRIPT} ${CLOSE_LABS_SCRIPT}

# Enable public read and execute for exerciser and submit scripts
# Disable all writes to prevent accidental modifications
chmod 555 ${EXERCISER_SCRIPT} ${SUBMIT_SCRIPT}

# Enable others to read due dates
chmod 644 ${DUE_DATES_FILE}

# Set permissions for lab files and their cases
LAB_DIRS=`find . -type d -name "lab*"`
for DIR in ${LAB_DIRS}; do
    chmod 751 ${DIR}

    # Enable read and execute on all test *scripts or binaries*
    ALL_CASES=`cat ${DIR}/test-cases | grep -E "^(public|private)" | cut -d ' ' -f 2 | sort | uniq`
    for CASE in ${ALL_CASES}; do
        chmod 755 ${DIR}/${CASE}/test ${DIR}/${CASE}/check-output
        [[ -f ${DIR}/${CASE}/pre-test ]] && chmod 755 ${DIR}/${CASE}/pre-test
        [[ -f ${DIR}/${CASE}/post-test ]] && chmod 755 ${DIR}/${CASE}/post-test
    done

    # Enable read and execute on *public case directories*
    # Allow group to read, don't allow others to read
    PUBLIC_CASES=`cat ${DIR}/test-cases | grep "^public" | cut -d ' ' -f 2`
    for CASE in ${PUBLIC_CASES}; do
        chmod 751 ${DIR}/${CASE}
    done
    
    # Enable all others to read 'test-cases' and 'required-files' files
    # Currently enable group members to write
    chmod 664 ${DIR}/test-cases ${DIR}/required-files
done


# This directory only needs execute bit for others, enable read for group
chmod 751 ${SCRIPT_DIR}

cd -

