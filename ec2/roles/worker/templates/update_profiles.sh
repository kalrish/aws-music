shopt -s nullglob

rm -f -- build-*/tup.config

for PROFILE in $(aws --query 'Parameters[].Name' --output text ssm get-parameters-by-path --path '/vibes/profiles')
do
	PROFILE_NAME="${PROFILE##*/}"
	mkdir -p "build-${PROFILE_NAME}"
	aws --query 'Parameter.Value' --output text ssm get-parameter --name "${PROFILE}" > "build-${PROFILE_NAME}/tup.config"
done
