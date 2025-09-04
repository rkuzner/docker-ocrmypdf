#!/bin/bash

# import log_message function
scriptFolder=$( cd "$( dirname "${0}" )" && pwd )
scriptBaseName=$( basename "${0}" .sh )
configFileName="${scriptFolder}/${scriptBaseName}.conf"
if [ -f "${configFileName}" ]; then
	# shellcheck disable=SC1090
	source "${configFileName}"
fi
if [ -n "${TOOL_NAME}" ]; then
	scriptBaseName="${scriptBaseName}-"$( echo ${TOOL_NAME} | tr "[:upper:]" "[:lower:]" )
fi
DEFAULT_LOG_FOLDER="/logs"
DEFAULT_SOURCE_FOLDER="/source"
DEFAULT_TARGET_FOLDER="/target"
DEFAULT_KEEP_SOURCEFILE="false"
DEFAULT_PROCESSED_FOLDER="/processed"

source "${scriptFolder}/log-message.sh"
set_logFolder "${LOG_FOLDER:-${DEFAULT_LOG_FOLDER}}"
set_logFileBaseName "${scriptBaseName}"

if [ -f "${configFileName}" ]; then
	log_message "Found Config file!"
else
	log_message "Config file not found: ${configFileName}, using default values"
fi

SOURCE_FOLDER="${SOURCE_FOLDER:-${DEFAULT_SOURCE_FOLDER}}"
TARGET_FOLDER="${TARGET_FOLDER:-${DEFAULT_TARGET_FOLDER}}"
PROCESSED_FOLDER="${PROCESSED_FOLDER:-${DEFAULT_PROCESSED_FOLDER}}"
KEEP_SOURCEFILE="${KEEP_SOURCEFILE:-${DEFAULT_KEEP_SOURCEFILE}}"

log_message "Checking folders..."
if [ ! -d "${SOURCE_FOLDER}" ]; then
	log_message_and_exit 11 "Invalid SOURCE_FOLDER: ${SOURCE_FOLDER}"
fi
if [ ! -r "${SOURCE_FOLDER}" ]; then
	log_message_and_exit 12 "Can not read from SOURCE_FOLDER: ${SOURCE_FOLDER}"
fi
if [ ! -w "${SOURCE_FOLDER}" ]; then
	log_message_and_exit 13 "Can not write on SOURCE_FOLDER: ${SOURCE_FOLDER}"
fi
if [ ! -d "${TARGET_FOLDER}" ]; then
	log_message_and_exit 14 "Invalid TARGET_FOLDER: ${TARGET_FOLDER}"
fi
if [ ! -r "${TARGET_FOLDER}" ]; then
	log_message_and_exit 15 "Can not read from TARGET_FOLDER: ${TARGET_FOLDER}"
fi
if [ ! -w "${TARGET_FOLDER}" ]; then
	log_message_and_exit 16 "Can not write on TARGET_FOLDER: ${TARGET_FOLDER}"
fi
if [ ! -d "${PROCESSED_FOLDER}" ]; then
	log_message_and_exit 17 "Invalid PROCESSED_FOLDER: ${PROCESSED_FOLDER}"
fi
if [ ! -r "${PROCESSED_FOLDER}" ]; then
	log_message_and_exit 18 "Can not read from PROCESSED_FOLDER: ${PROCESSED_FOLDER}"
fi
if [ ! -w "${PROCESSED_FOLDER}" ]; then
	log_message_and_exit 19 "Can not write on PROCESSED_FOLDER: ${PROCESSED_FOLDER}"
fi
log_message "Found valid folders!"

log_message "Checking for source files"
folderContents=$( ls -1 "${SOURCE_FOLDER}" )
if [ -z "${folderContents}" ]; then
	log_message "No files found on source folder."
	log_message "Nothing to do!"
	exit 0
fi

log_message "Iterating source files: ${SOURCE_FOLDER}"
#log_message "DEBUG: folderContents: ${folderContents}"
# must be able to iterate on filenames that have spaces on them
originalIFS="${IFS}"
IFS=$'\n'
for individualFile in ${folderContents}; do
	#log_message "DEBUG: individualFile: ${SOURCE_FOLDER}/${individualFile}"

	if [ -d "${SOURCE_FOLDER}/${individualFile}" ]; then
		log_message "Found a directory! Ignoring: ${individualFile}"
	fi
	if [ ! -d "${SOURCE_FOLDER}/${individualFile}" ]; then
		log_message "Processing source file: ${individualFile}"
		#log_message "DEBUG: will run ocrmypdf -l spa "${SOURCE_FOLDER}/${individualFile}" "${TARGET_FOLDER}/${individualFile}""
		ocrmypdf -l spa "${SOURCE_FOLDER}/${individualFile}" "${TARGET_FOLDER}/${individualFile}" 2>&1 | tee -a "$( get_logFileName )"
		ocrResult=${?}
		if [ ${ocrResult} -eq 0 ]; then
			# should match target's timestamps with source's timestamps
			log_message "Updating target's timestamps..."
			touch -r "${SOURCE_FOLDER}/${individualFile}" "${TARGET_FOLDER}/${individualFile}"

			# if ocr successful, either keep or remove original (if aplicable)
			if [ "${KEEP_SOURCEFILE}" == "true" ] ; then
				log_message "Moving source file to processed folder..."
				mv -n "${SOURCE_FOLDER}/${individualFile}" "${PROCESSED_FOLDER}"
			fi
			if [ "${KEEP_SOURCEFILE}" == "false" ] ; then
				log_message "Removing source file..."
				rm -f "${SOURCE_FOLDER}/${individualFile}"
			fi
		else
			log_message "Could not ocr file! (ocrmypdf errCode: ${ocrResult})"
		fi
	fi

done
# restore originalIFS
IFS="${originalIFS}"

log_message "No more files!"
