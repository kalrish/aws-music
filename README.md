#  AWS-based music compilation system


##  Deployment

 1.  Deploy a new CloudFormation stack based on `cfn/main.yaml`.
 
 2.  Push the build code to your newly-created private mirror.
 
     $  git remote add codecommit ssh://git-codecommit.eu-central-1.amazonaws.com/v1/repos/music
	 $  git push codecommit master
 
 3.  Upload your music sources to the source bucket.
 
 4.  Create the necessary EC2 keypairs.
 
 5.  Build the worker AMI.
 
 6.  Build the server AMI.
