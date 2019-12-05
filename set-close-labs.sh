#!/bin/bash
# Sets the labs to auto-close given the due dates in the lab-due-dates file.
# Uses the 'at' utility, so assumes the EECG system continues to support it.
#
SCRIPT_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))

ALL_DUE_DATES=`cat ${SCRIPT_DIR}/lab-due-dates | grep "^lab"`

MONTH_NUM=`date +%m`
if [[ ${MONTH_NUM} -le 4 ]]; then
	COURSE_CODE=ece361s
elif [[ ${MONTH_NUM} -ge 9 ]]; then
	COURSE_CODE=ece361f
else
    echo "ERROR: No course in the summer... why are you here?"
    exit 1
fi
SUBMISSION_DIR=/local1/tester/${COURSE_CODE}

IFS=$'\n'
for LINE in ${ALL_DUE_DATES}; do
    LAB_NUM=`echo ${LINE} | cut -d ' ' -f 1 | sed 's/lab//g'`
    DUE_DATE=`echo ${LINE} | cut -d ' ' -f 2-`
    DUE_DATE_UNIX=`date -d "${DUE_DATE}" +%s`
    echo "Lab ${LAB_NUM} is due by ${DUE_DATE} (Unix time: ${DUE_DATE_UNIX})"

    # Calculate time offset in *minutes*
    # 'at' jobs are unable to use sub-minute granularities
    # Add small offset of 1 extra min to account for floored fractional
    # results and possible time drift between computers.
    NOW=`date +%s`
    TIME_DIFF=`echo "1 + (${DUE_DATE_UNIX} - ${NOW}) / 60" | bc`
    echo -e "\t${TIME_DIFF} minutes in the future"

    echo -e "\tSetting 'at' job to close Lab ${LAB_NUM} in ${TIME_DIFF} minutes"
    COMMAND="cd ${SUBMISSION_DIR}
if [[ -d ${LAB_NUM} ]]; then
    mv ${LAB_NUM} ${LAB_NUM}.done
fi
"
    echo "Job script:"
    echo "${COMMAND}"
    echo "${COMMAND}" | at now + ${TIME_DIFF} minutes
    echo
done

