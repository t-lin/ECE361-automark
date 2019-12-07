#!/bin/bash
# To be run by the marking TA in a directory containing all the submissions
#   - e.g. Each subdirectory is the UTORid of a student who submitted
#

CURR_DIR=`pwd`
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source ${SCRIPT_DIR}/echoHelpers

if [[ $# -ne 1 ]]; then
    SCRIPT_NAME=$(basename ${BASH_SOURCE[0]}) # Works w/ symbolic links
    bold_red "ERROR: Expecting one parameter (the lab #)"
    bold_blue "Usage: ${SCRIPT_NAME} <lab #>"
    exit 1
else
    LAB_NUM=$1
fi

# Path to MOSS script, assume in current directory for now
MOSS_SCRIPT=${CURR_DIR}/moss
if [[ ! -f ${MOSS_SCRIPT} ]]; then
    bold_red "ERROR: MOSS script does not exist at ${MOSS_SCRIPT}"
    exit 1
fi

# Directory where all the marking files and scripts are
LAB_DIR=${SCRIPT_DIR}/lab${LAB_NUM}
if [[ ! -d ${LAB_DIR} ]]; then
    bold_red "ERROR: lab${LAB_NUM} directory does not exist"
    bold_red "       Please report this to the head TA"
    exit 1
fi

if [[ ! -f ${LAB_DIR}/required-files ]]; then
    bold_red "ERROR: lab${LAB_NUM} directory is missing the 'required-files' file"
    bold_red "       Please report this to the head TA"
    exit 1
fi
REQ_FILES=`cat ${LAB_DIR}/required-files | grep -v "^#"`
REQ_BASENAMES=`for FILE in ${REQ_FILES}; do echo $(basename ${FILE}); done`

# For each required file, check all the submissions
for FILE in ${REQ_BASENAMES}; do
    bold_blue "Submitting ${FILE} to MOSS for analysis. This may take some time..."

    # TODO: Configure parameters based on per-lab config file
    ${MOSS_SCRIPT} -m 5 -l python -d */${FILE} >> moss.log 2>&1
    MOSS_RESULTS_URL=`tail -n1 moss.log`
    if [[ "${MOSS_RESULTS_URL}" =~ ^http ]]; then
        bold_green "MOSS results for ${FILE} are at: ${MOSS_RESULTS_URL}"
    else
        bold_yellow "WARNING: MOSS did not return results for ${FILE}"
    fi
done

