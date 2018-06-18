#!/usr/bin/bash


set -ex

declare -A EXIST

for PROFILE in "$(aws --query 'Parameters[?ends_with(@.Name,`config`)].{Path:Name,Config:Value}' --output json ssm get-parameters-by-path --recursive --path '/music/profiles' | jq -c '.[]')"
do
	PROFILE_NAME="$(jq -r '.Path' <<< "$PROFILE" | sed -e 's|/music/profiles/\(.*\)/config|\1|')"
	EXIST["${PROFILE_NAME}"]=1
	mkdir -p "{{ profiles_dir }}/build-${PROFILE_NAME}"
	jq -r '.Config' <<< "${PROFILE}" > "{{ profiles_dir }}/build-${PROFILE_NAME}/tup.config"
done

#for PROFILE in "{{ profiles_dir }}"/build-*/tup.config
#do
#	if [[ -z "${EXIST["${PROFILE}"]}" ]]
#	then
#		rm -fr -- "build-${}"
#	fi
#done
