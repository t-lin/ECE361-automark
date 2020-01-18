#!/bin/bash
# To be run by students as an exercisor (to check output formatting and etc.)
# The directory where this is run should contain all the student's submissions.
#
# Possible return statuses:
#   - 0: All good
#   - 1: Files were missing, abort
#   - 10: One or more tests failed.
#         Test failure may be due to missing files that were ignored.
#         TODO: Figure out a way to differentiate between these two cases.

CURR_DIR=`pwd`
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
if [[ -f /usr/local/ece361-wrapper-prints ]]; then
    # Running within VM
    source /usr/local/ece361-wrapper-prints
else
    source ${SCRIPT_DIR}/echoHelpers
fi
unset ERR

if [[ $# -ne 1 ]]; then
    SUBMIT_CMD=$(basename ${BASH_SOURCE[0]}) # Works w/ symbolic links
    bold_red "ERROR: Expecting exactly one parameter (the lab #)"
    bold_blue "Usage format:"
    blue "\t${SUBMIT_CMD} <lab #>"
    exit 1
else
    LAB_NUM=$1
fi

# Timeout for tests to run, in seconds
TEST_TIMEOUT=60

# Directory where all the marking files and scripts are
LAB_DIR=${SCRIPT_DIR}/lab${LAB_NUM}
if [[ ! -d ${LAB_DIR} ]]; then
    bold_red "ERROR: lab${LAB_NUM} directory does not exist"
    bold_red "       Please report this to the head TA"
    exit 1
fi

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

# Go through all the test cases
# If any error is encountered, continue on to next case
NUM_FAILED=0
NUM_PASSED=0
NUM_SKIPPED=0
for ((i = 0; i < ${NUM_CASES}; i++)); do
    echo; echo;
    CASE=${TEST_CASES[${i}]}

    bold_blue "=================================================="
    bold_blue "Running case ${CASE}"
    bold_blue "=================================================="

    # Ensure mandatory scripts 'test' and 'check-output' exist
    checkRequiredScript ${LAB_DIR}/${CASE}/test
    if [[ $? -ne 0 ]]; then
        bold_red "\tPlease report this to the head TA"
        bold_red "\tSkipping this case..."
        NUM_SKIPPED=`echo "${NUM_SKIPPED} + 1" | bc`
        continue
    fi
    checkRequiredScript ${LAB_DIR}/${CASE}/check-output
    if [[ $? -ne 0 ]]; then
        bold_red "\tPlease report this to the head TA"
        bold_red "\tSkipping this case..."
        NUM_SKIPPED=`echo "${NUM_SKIPPED} + 1" | bc`
        continue
    fi

    # Pre-test is OPTIONAL. Run it if it exists.
    checkOptionalAndRun ${LAB_DIR}/${CASE}/pre-test

    # Run test, redirect stderr to stdout, then write out to file
	# If test process lasts longer than 60 seconds, kill it
	timeout -s 9 ${TEST_TIMEOUT} ${LAB_DIR}/${CASE}/test > ${CASE}-output.log 2>&1
	if [[ $? -eq 137 ]]; then
		bold_red "ERROR: Test case ${CASE} for ${UTORID} timed out (${TEST_TIMEOUT} seconds) and was killed"
		bold_red "       This may be due to an infinite loop, please check manually"
	fi

    # Post-test is OPTIONAL. Run it if it exists.
    checkOptionalAndRun ${LAB_DIR}/${CASE}/post-test

    # Checking output is non-optional
    # Prints out 0 on failure, 1 on success
    ${LAB_DIR}/${CASE}/check-output ${CASE}-output.log
    if [[ $? -eq 0 ]]; then
        bold_green "Success :D"
        NUM_PASSED=`echo "${NUM_PASSED} + 1" | bc`
    elif [[ $? -eq 1 ]]; then
        bold_red "Failed :("
        NUM_FAILED=`echo "${NUM_FAILED} + 1" | bc`
    fi
done

echo; echo;
bold_blue "=================================================="
bold_blue "Summary of tests:"
bold_blue "=================================================="
bold_green "Passed: ${NUM_PASSED} out of ${NUM_CASES}"
bold_red "Failed: ${NUM_FAILED} out of ${NUM_CASES}"
if [[ ${NUM_SKIPPED} -gt 0 ]]; then
    bold_yellow "Skipped: ${NUM_SKIPPED} out of ${NUM_CASES}"
fi
echo

# Move log files and return to previous directory
mv *-output.log ${CURR_DIR}
cd ${CURR_DIR}
rm -rf ${TMP_DIR} # Clean-up

if [[ ${NUM_FAILED} -eq 0 ]]; then
    exit 0
elif [[ ${NUM_FAILED} -gt 0 || ${IGNORE_MISSING_FILES} =~ [yY] ]]; then
    # If IGNORE_MISSING_FILES was specified, return status code 10
    exit 10 # See status codes in comments above
fi
