AWS-based music compilation system
================================================================================

In this repository are two implementations, both based on the Amazon Web Services cloud platform, of the [vibes](https://www.davidjsp.eu/vibes/index) music compilation system.


Deployment
--------------------------------------------------------------------------------

 1.  Clone this repository.
 
 2.  Deploy a new CloudFormation stack based on the `cfn/main.yaml` template.
 
 3.  If you chose to create a private CodeCommit repository, push the code to it.
 
     From within your clone directory:
     
         $  git remote add codecommit ssh://git-codecommit.eu-central-1.amazonaws.com/v1/repos/vibes
         $  git remote add codecommit https://git-codecommit.eu-central-1.amazonaws.com/v1/repos/vibes
         $  git push codecommit master
     
     You might need to configure git or the SSH client. If need be, refer to the official AWS docs.
 
 4.  Upload your music sources to the source bucket.
 
         $  aws s3 sync /path/to/music/sources "s3://$(aws --query 'Parameter.Value' --output text ssm get-parameter --name /vibes/sources)"
 
 5.  Deploy a new CloudFormation stack based on the `cfn/profile.yaml` template for each profile.
 
     The tup configuration may be entered directly or uploaded using the AWS CLI:
     
         $  aws ssm put-parameter --overwrite --name "/vibes/profiles/${PROFILE}" --type String --value "file://${PROFILE}.config"
 
 6.  Continue with the instructions specific to the implementation of your choice.
