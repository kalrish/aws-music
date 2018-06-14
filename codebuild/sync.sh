#!/bin/bash


if [[ $# -eq 2 ]]
then
	declare -r PROFILE="${1}" DESTDIR="${2}"
	if BUCKET="$(aws --query 'Parameter.Value' --output text ssm get-parameter --name "/music/profiles/${PROFILE}/artifacts")"
	then
		aws s3 sync --quiet "s3://${BUCKET}/music-run-${PROFILE}" "${DESTDIR}"
	else
		echo 'error: could not retrieve bucket name from parameter store'
	fi
elif [[ $# -eq 0 ]]
then
	echo 'error: missing argument: profile'
	echo 'error: missing argument: destination directory'
elif [[ $# -eq 1 ]]
then
	echo 'error: missing argument: destination directory'
else
	echo 'error: too many arguments'
fi
