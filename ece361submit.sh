#!/bin/bash
# Wrapper script around EECG's submitece361* commands
# Ensures necessary files exist before submitting
#
# Usage format:
#   ece361submit <lab num>
#
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
source ${SCRIPT_DIR}/echoHelpers
unset ERR

MONTH_NUM=`date +%m`
if [[ ${MONTH_NUM} -le 4 ]]; then
    EECG_SUBMIT=submitece361s
elif [[ ${MONTH_NUM} -ge 9 ]]; then
    EECG_SUBMIT=submitece361f
else
    bold_red "ERROR: No course in the summer... why are you here?"
    exit 1
fi

# Get lab number
if [[ $# -ne 1 ]]; then
    bold_blue "Usage format:"
    blue "\tece361submit <lab num>"
    exit 1
else
    LAB_NUM=$1

    # Check if directory for the lab exists
    if [[ ! -d "${SCRIPT_DIR}/lab${LAB_NUM}" ]]; then
        bold_red "ERROR: Lab ${LAB_NUM} does not exist (or submission is not ready yet)"
        exit 1
    fi
fi

# Check if due date for this lab has passed
DUE_DATE=`cat ${SCRIPT_DIR}/lab-due-dates | grep "^lab${LAB_NUM}" | cut -d ' ' -f 2-`
if [[ -n ${DUE_DATE} ]]; then
    DUE_DATE_UNIX=`date -d "${DUE_DATE}" +%s`
    NOW=`date +%s`
    if [[ ${NOW} -gt ${DUE_DATE_UNIX} ]]; then
        bold_yellow "Due date for Lab ${LAB_NUM} (${DUE_DATE}) has passed."
        bold_yellow -n "Continue with late submission? (yes/no) => "
        read IGNORE_LATE_SUBMIT
        echo
        if [[ ${IGNORE_LATE_SUBMIT} =~ [nN] ]]; then
            exit 0
        fi
    fi
else
    bold_red "ERROR: No due date found in due dates file"
    bold_red "       Please report this to the head TA"
    exit 1
fi

# Directory where all the marking files and scripts are
LAB_DIR=${SCRIPT_DIR}/lab${LAB_NUM}

# IGNORE_MISSING_FILES *may* have been set by a calling script, or by the user
# If it's not yes, or it hasn't been set yet, then check if required files exist
REQ_FILES=`cat ${LAB_DIR}/required-files | grep -v "^#"`
if [[ ! $IGNORE_MISSING_FILES =~ [yY] ]]; then
    unset MISSING_FILES
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
            exit 1
        fi
    fi
fi

# EECG's submit command requires files to be submitted from current directory
# Create a temporary directory, copy files there, run submit from there, then clean-up
TMP_DIR=`mktemp -d`
chmod og-rwx ${TMP_DIR}
cp -a ${REQ_FILES} ${TMP_DIR}/ 2> /dev/null
cd ${TMP_DIR}
if [[ `ls` ]]; then
    ${EECG_SUBMIT} ${LAB_NUM} *
else
    bold_red "ERROR: Nothing to submit"
fi

cd -
rm -rf ${TMP_DIR}

# List submissions for students to confirm
echo
bold_blue "Listing submissions..."
${EECG_SUBMIT} -l ${LAB_NUM}

