#!/bin/bash
# To be run by students as an exercisor (to check output formatting and etc.)
# The directory should contain the student's submissions (with relative paths
# specified similar to the submission script)
#
# Possible return statuses:
#   - 0: All good
#   - 1: Files were missing, bail out
#   - 10: Files were missing, ignore and continue

CURR_DIR=`pwd`
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
source ${SCRIPT_DIR}/echoHelpers
unset ERR

if [[ $# -ne 1 ]]; then
    SUBMIT_CMD=$(basename $0) # Works w/ symbolic links
    bold_red "ERROR: Expecting exactly one parameter (the lab #)"
    bold_blue "Usage format:"
    blue "\t${SUBMIT_CMD} <lab #>"
    exit 1
else
    LAB_NUM=$1
fi

# Directory where all the marking files and scripts are
LAB_DIR=${SCRIPT_DIR}/lab${LAB_NUM}

# Ensure required files exist
unset MISSING_FILES
REQ_FILES=`cat ${LAB_DIR}/required-files | grep -v "^#"`
for FILE in ${REQ_FILES}; do
    if [[ ! -f ${FILE} ]]; then
        bold_yellow "WARNING: ${FILE} does not exist"
        MISSING_FILES=1
    fi
done

if [[ -n ${MISSING_FILES} ]]; then
    echo
    bold_yellow "One or more required files for lab are missing."
    bold_yellow "You may be in the wrong directory, or have not yet completed the lab."
    bold_yellow -n "Ignore and continue? (yes/no) => "
    read IGNORE_MISSING_FILES
    echo

    if [[ ! ${IGNORE_MISSING_FILES} =~ [yY] ]]; then
        exit 1 # See status codes in comments above
    fi
fi

# Read in test cases and marks per case
TEST_CASES=(`cat ${LAB_DIR}/test-cases | grep -E "^public" | cut -d ' ' -f 2`)
NUM_CASES=${#TEST_CASES[*]}

# Check if the optional scripts exist and is executable. If so, run it.
function checkOptionalAndRun() {
    FILE=$1

    if [[ -f ${FILE} && -x ${FILE} ]]; then
        ${FILE}
    fi
}

# Validate required scripts to see if they exist and is executable.
# If not, print out warning and return 255.
function checkRequiredScript() {
    FILE=$1

    if [[ ! -f ${FILE} || ! -x ${FILE} ]]; then
        BASENAME=$(basename ${FILE})
        bold_red "ERROR:\tCase '${CASE}' is missing required file '${BASENAME}'"
        return 255
    fi
}

# Test scripts assume all files are in the same directory.
# This may not always be the case (e.g. lab has multiple sections), and
# plus, 'required-files' allows relative paths.
#
# Work-around: Create temp dir, copy files there, runs tests from there,
# move the resulting log files back, and clean-up the temp dir.
TMP_DIR=`mktemp -d`
chmod og-rwx ${TMP_DIR}
cp -a ${REQ_FILES} ${TMP_DIR}/ 2> /dev/null
cd ${TMP_DIR}
echo

# Go through all the test cases
# If any error is encountered, continue on to next case
for ((i = 0; i < ${NUM_CASES}; i++)); do
    CASE=${TEST_CASES[${i}]}

    bold_blue "=================================================="
    bold_blue "Running case ${CASE}"
    bold_blue "=================================================="

    # Ensure mandatory scripts 'test' and 'check-output' exist
    checkRequiredScript ${LAB_DIR}/${CASE}/test
    if [[ $? -ne 0 ]]; then
        bold_red "\tPlease report this to the head TA"
        bold_red "\tSkipping this case..."
        continue
    fi
    checkRequiredScript ${LAB_DIR}/${CASE}/check-output
    if [[ $? -ne 0 ]]; then
        bold_red "\tPlease report this to the head TA"
        bold_red "\tSkipping this case..."
        continue
    fi

    # Pre-test is OPTIONAL. Run it if it exists.
    checkOptionalAndRun ${LAB_DIR}/${CASE}/pre-test

    # Run test, redirect stderr to stdout, then write out to file
    ${LAB_DIR}/${CASE}/test 2>&1 > ${CASE}-output.log

    # Post-test is OPTIONAL. Run it if it exists.
    checkOptionalAndRun ${LAB_DIR}/${CASE}/post-test

    # Checking output is non-optional
    # Prints out 0 on failure, 1 on success
    ${LAB_DIR}/${CASE}/check-output ${CASE}-output.log
    if [[ $? -eq 0 ]]; then
        bold_green "Success :D"
    elif [[ $? -eq 1 ]]; then
        bold_red "Failed :("
    fi

    echo; echo;
done

# Move log files and return to previous directory
mv *-output.log ${CURR_DIR}
cd ${CURR_DIR}
rm -rf ${TMP_DIR} # Clean-up

# If IGNORE_MISSING_FILES was specified, return status code 10
if [[ ${IGNORE_MISSING_FILES} =~ [yY] ]]; then
    exit 10 # See status codes in comments above
fi
