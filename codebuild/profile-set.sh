#!/bin/bash


aws ssm put-parameter --overwrite --name "/music/profiles/${1:?Profile not specified}/config" --type String --value "${2:-file://${1}.config}"
