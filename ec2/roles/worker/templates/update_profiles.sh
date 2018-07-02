shopt -s nullglob

rm -f -- build-*/tup.config

aws --query 'Parameters[].{Path:Name,Config:Value}' --output json ssm get-parameters-by-path --path '/vibes/profiles' | jq -c '.[]' | while read PROFILE
do
	PROFILE_NAME="$(jq -r '.Path' <<< "$PROFILE")"
	PROFILE_NAME="${PROFILE_NAME##*/}"
	mkdir -p "build-${PROFILE_NAME}"
	jq -r '.Config' <<< "${PROFILE}" > "build-${PROFILE_NAME}/tup.config"
done
