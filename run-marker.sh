#!/bin/bash
# To be run in the directory containing all the student's submissions
#   - e.g. Each subdirectory is the UTORid of a student who submitted
#
# Will create an output file in the same directory (./labX-results.csv)
#

if [[ $# -ne 1 ]]; then
    bold_red "ERROR: Expecting one parameter (the lab #)"
    bold_blue "Usage: run-marker.sh <lab #>"
    exit 1
else
    LAB_NUM=$1
fi

SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
source ${SCRIPT_DIR}/echoHelpers

# Directory where all the marking files and scripts are
LAB_DIR=${SCRIPT_DIR}/lab${LAB_NUM}

# Read in list of students in the course (by UTORid)
STUDENT_LIST=`cat ${SCRIPT_DIR}/students-list | grep "^[a-z]"`

# Define results file to store marking data
# Back up results file if one already exists
RESULTS_FILE=${SCRIPT_DIR}/lab${LAB_NUM}-results.csv
if [[ -f ${RESULTS_FILE} ]]; then
    mv ${RESULTS_FILE} ${RESULTS_FILE}.`date +%s`
fi

# Read in test cases and marks per case
TEST_CASES=(`cat ${LAB_DIR}/test-cases | grep -E "^private" | cut -d ' ' -f 2`)
CASE_MARKS=(`cat ${LAB_DIR}/test-cases | grep -E "^private" | cut -d ' ' -f 3`)
NUM_CASES=${#TEST_CASES[*]}

# Sanity check: Make sure all private tests have an associated mark
if [[ ${NUM_CASES} -ne ${#CASE_MARKS[*]} ]]; then
    bold_red "ERROR: All test cases must have an associated mark"
    exit 1
fi

# Sanity check: Ensure marks are positive numbers
NUM_REGEX="^[0-9]+([.][0-9]+)?$"
for MARK in ${CASE_MARKS[*]}; do
    if [[ ! ${MARK} =~ ${NUM_REGEX} ]]; then
        bold_red "ERROR: ${MARK} is not a valid number"
        exit 1
    fi
done

# Check if the optional scripts exist and is executable. If so, run it.
function checkOptionalAndRun() {
    FILE=$1

    if [[ -f ${FILE} && -x ${FILE} ]]; then
        ${FILE}
    fi
}

# Validate required scripts to see if they exist and is executable.
# If not, print out error and quit.
function checkRequiredFiles() {
    FILE=$1

    if [[ ! -f ${FILE} || ! -x ${FILE} ]]; then
    #if [[ ! -f ${FILE} ]]; then
        BASENAME=$(basename ${FILE})
        bold_red "ERROR:\tCase '${CASE}' is missing required file '${BASENAME}'"
        bold_red "\tAborting the remaining tests"
        exit 1
    fi
}

# For each student, go through all the test cases
for UTORID in ${STUDENT_LIST}; do
    # See if a submission exists (directory w/ the UTORid)
    if [[ ! -d ${UTORID} ]]; then
        # Either the student didn't submit or his/her partner did
        # TODO: Account for the case of partners
        continue
    fi

    RESULT_LINE=${UTORID}

    for ((i = 0; i < ${NUM_CASES}; i++)); do
        CASE=${TEST_CASES[${i}]}
        MARK=${CASE_MARKS[${i}]}

        bold_blue "=================================================="
        bold_blue "Running case ${CASE} for ${UTORID}"
        bold_blue "=================================================="

        # Ensure mandatory scripts 'test' and 'check-output' exist
        checkRequiredFiles ${LAB_DIR}/${CASE}/test
        checkRequiredFiles ${LAB_DIR}/${CASE}/check-output

        # Pre-test is OPTIONAL. Run it if it exists.
        checkOptionalAndRun ${LAB_DIR}/${CASE}/pre-test

        # Run test, redirect stderr to stdout, then write out to file
        ${LAB_DIR}/${CASE}/test 2>&1 > ${UTORID}/output

        # Post-test is OPTIONAL. Run it if it exists.
        checkOptionalAndRun ${LAB_DIR}/${CASE}/post-test

        # Checking output is non-optional
        # Prints out 0 on failure, 1 on success
        ${LAB_DIR}/${CASE}/check-output ${UTORID}/output
        if [[ $? -eq 0 ]]; then
            bold_green "Success :D +${MARK}"
            RESULT_LINE+=,${MARK}
        elif [[ $? -eq 1 ]]; then
            bold_red "Failed :("
            RESULT_LINE+=,0
        fi

        echo; echo;
    done

    echo ${RESULT_LINE} >> ${RESULTS_FILE}
done

echo; echo;
bold_green "Done. See results in ${RESULTS_FILE}"
echo

