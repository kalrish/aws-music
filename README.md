#  AWS-based music compilation system


What is this?
--------------------------------------------------------------------------------

The 


Deployment
--------------------------------------------------------------------------------

 1.  Clone this repository.
 
 2.  Deploy a new CloudFormation stack based on the `cfn/main.yaml` template.
 
 3.  Push the code to your newly-created repository.
 
     From within your clone directory:
     
         $  git remote add codecommit ssh://git-codecommit.eu-central-1.amazonaws.com/v1/repos/music
         $  git remote add codecommit https://git-codecommit.eu-central-1.amazonaws.com/v1/repos/music
         $  git push codecommit master
     
     You might need to configure git or the SSH client. If need be, refer to the official AWS docs.
 
 4.  Upload your music sources to the source bucket.
 
         $  aws s3 sync /path/to/music/sources "s3://$(aws --query 'Parameter.Value' --output text ssm get-parameter --name /music/sources)"
 
 5.  Deploy a new CloudFormation stack based on the `cfn/profile.yaml` template for each music profile.
 
 6.  Upload the settings for each profile to the relevant SSM parameters.
 
     Use the CLI for this, because tup.config files contain relevant newlines. For example:
     
         $  for PROFILE in flac phone car ; do aws ssm put-parameter --overwrite "/music/profiles/${PROFILE}/config" --type String --value "file://${PROFILE}.config" ; done
