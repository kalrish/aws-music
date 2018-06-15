#!/bin/bash


aws --query 'Parameter.Value' --output text ssm get-parameter --name "/music/profiles/${1:?Profile not specified}/config"
