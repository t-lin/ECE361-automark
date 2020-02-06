#!/bin/bash
# To be run by the marking TA in a directory containing all the submissions
#   - e.g. Each subdirectory is the UTORid of a student who submitted
#
# NOTE: Since this script will check for submission dates, shoulud copy the
#       student's submission directory with cp -a to preserve attributes
#
# Will create an output file in the same directory (./labX-results.csv)
#

CURR_DIR=`pwd`
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
source ${SCRIPT_DIR}/echoHelpers

if [[ $# -ne 1 ]]; then
    MARKER_CMD=$(basename ${BASH_SOURCE[0]}) # Works w/ symbolic links
    bold_red "ERROR: Expecting one parameter (the lab #)"
    bold_blue "Usage: ${MARKER_CMD} <lab #>"
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

# Read in list of teams in the course (by UTORid)
if [[ ! -f ${SCRIPT_DIR}/student-teams ]]; then
    bold_red "ERROR: student-teams file does not exist"
    bold_red "       Please report this to the head TA"
    exit 1
fi
STUDENT_LIST=`cat ${SCRIPT_DIR}/student-teams | grep "^[a-z]"`

# Define results file to store marking data
# Back up results file if one already exists
RESULTS_FILE=${CURR_DIR}/lab${LAB_NUM}-results.csv
if [[ -f ${RESULTS_FILE} ]]; then
    mv ${RESULTS_FILE} ${RESULTS_FILE}.`date +%s`
fi

MISSING_SUBMIT_LOG=${CURR_DIR}/missing-submissions.log
if [[ -f ${MISSING_SUBMIT_LOG} ]]; then
    mv ${MISSING_SUBMIT_LOG} ${MISSING_SUBMIT_LOG}.`date +%s`
fi

LATE_SUBMIT_LOG=${CURR_DIR}/late-submissions.log
if [[ -f ${LATE_SUBMIT_LOG} ]]; then
    mv ${LATE_SUBMIT_LOG} ${LATE_SUBMIT_LOG}.`date +%s`
fi

DUE_DATE=`cat ${SCRIPT_DIR}/lab-due-dates | grep "^lab${LAB_NUM}" | cut -d ' ' -f 2-`
if [[ -n ${DUE_DATE} ]]; then
    DUE_DATE_UNIX=`date -d "${DUE_DATE}" +%s`
else
    bold_red "ERROR: No due date found in due dates file"
    bold_red "       Please report this to the head TA"
    exit 1
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
function checkRequiredScript() {
    FILE=$1

    if [[ ! -f ${FILE} || ! -x ${FILE} ]]; then
        BASENAME=$(basename ${FILE})
        bold_red "ERROR:\tCase '${CASE}' is missing required file '${BASENAME}'"
        bold_red "\tAborting the remaining tests"
        exit 1
    fi
}

# Create title row in the grade file
RESULT_LINE="UTORid"
for CASE in ${TEST_CASES[*]}; do
    RESULT_LINE+=,${CASE}
done
RESULT_LINE+=",Total"
echo ${RESULT_LINE} > ${RESULTS_FILE}

# Takes 1 input parameter:
#   1) Comma-delimited list of UTORid's
#
# Check if there are multiple students (e.g. a team)
# If there are, figure out which member submitted
# If multiple members submitted, find the one who submitted the latest
#
# Sets 'UTORID' to the latest that submitted, or nothing if no one submitted
function findLatestSubmitter() {
    unset UTORID

    MEMBERS=(`echo $1 | sed 's/,/ /g'`)
    if [[ ${#MEMBERS[*]} -gt 1 ]]; then
        LATEST_TIMESTAMP=0

        for MEMBER_UTORID in ${MEMBERS[*]}; do
            if [[ -d ${MEMBER_UTORID} ]]; then
                TIMESTAMP=`stat -c %Y ${MEMBER_UTORID}`
                if [[ ${TIMESTAMP} -gt ${LATEST_TIMESTAMP} ]]; then
                    LATEST_TIMESTAMP=${TIMESTAMP}
                    UTORID=${MEMBER_UTORID}
                fi
            fi
        done
    else
        if [[ -d ${MEMBERS} ]]; then
            UTORID=${MEMBERS}
        fi
    fi
}

# Takes two input parameters:
#   1) Comma-delimited list of UTORid's
#   2) Comma-delimited list of marks to assign (starting with comma)
#       - One per test case, plus total at the end
#       - e.g. ,1,2,3,4,10
function writeGradeFile() {
    MEMBERS=(`echo $1 | sed 's/,/ /g'`)
    MARKS=$2
    for MEMBER_UTORID in ${MEMBERS[*]}; do
        if [[ -n ${MARKS} ]]; then
            echo ${MEMBER_UTORID}${MARKS} >> ${RESULTS_FILE}
        else
            echo ${MEMBER_UTORID} >> ${RESULTS_FILE}
        fi
    done
}

# For each team/student, go through all the test cases
for LINE in ${STUDENT_LIST}; do
    findLatestSubmitter $LINE # Sets 'UTORID' to latest submitter

    # If 'UTORID' has not been set (or is empty), then no one submitted
    # Create entries in results file, but leave marks empty
    if [[ ! -n ${UTORID} ]]; then
        bold_yellow "WARNING: No submission for ${LINE}"
        echo ${LINE} >> ${MISSING_SUBMIT_LOG}
        writeGradeFile $LINE
        continue
    fi

    # Check if submission was late
    SUBMIT_TIME=`ls -l -d ${UTORID} | awk '{print $6,$7,$8}'`
    SUBMIT_TIME_UNIX=`date -d "${SUBMIT_TIME}" +%s`
    if [[ ${SUBMIT_TIME_UNIX} -gt ${DUE_DATE_UNIX} ]]; then
        echo ${UTORID} >> ${LATE_SUBMIT_LOG}
    fi

    unset RESULT_LINE
    TOTAL_MARK=0

    cd ${CURR_DIR}/${UTORID}
    for ((i = 0; i < ${NUM_CASES}; i++)); do
        CASE=${TEST_CASES[${i}]}
        MARK=${CASE_MARKS[${i}]}

        bold_blue "=================================================="
        bold_blue "Running case ${CASE} for ${UTORID}"
        bold_blue "=================================================="

        # Ensure mandatory scripts 'test' and 'check-output' exist
        checkRequiredScript ${LAB_DIR}/${CASE}/test
        checkRequiredScript ${LAB_DIR}/${CASE}/check-output

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
            bold_green "Success :D +${MARK}"
            RESULT_LINE+=,${MARK}
            TOTAL_MARK=`echo "${TOTAL_MARK} + ${MARK}" | bc`
        elif [[ $? -eq 1 ]]; then
            bold_red "Failed :("
            RESULT_LINE+=,0
        fi

        echo; echo;
    done

    RESULT_LINE+=,${TOTAL_MARK}
    writeGradeFile $LINE ${RESULT_LINE}

    cd ${CURR_DIR}
done

echo; echo;
bold_green "Done. See results in ${RESULTS_FILE}"
if [[ -f ${LATE_SUBMIT_LOG} ]]; then
    bold_green "See list of late submitters in ${LATE_SUBMIT_LOG}"
fi
if [[ -f ${MISSING_SUBMIT_LOG} ]]; then
    bold_green "See list of missing submitters in ${MISSING_SUBMIT_LOG}"
fi
echo

