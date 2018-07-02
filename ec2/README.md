EC2 implementation
================================================================================

This implementation is based on EC2 and provides much more flexibility, albeit with greater complexity, than the CodeBuild one. It comprises a VPC with a private and a public subnet, two EBS volumes to contain a copy of the sources and the compressed files, respectively, and various instances performing different tasks. The output is made available through servers via a variety of protocols.


Advantages
--------------------------------------------------------------------------------

###  Advantages

 -  **Incremental builds.** Unless your collection consists of a couple albums, you won't want to build it from scratch each and every time.
 -  **Fully flexible with regards to download methods.** You are not bound to use `aws s3 sync`; instead, a variety of protocols are available, such as SSHFS or rsync.

###  Disadvantages

 -  **More complex.** Just have a look at the deployment instructions below.
 -  **More expensive.**


Deployment
--------------------------------------------------------------------------------

 1.  Set up the VPC.

     If you wish to create a new VPC, go ahead and deploy a new CloudFormation stack based on the `ec2/cfn/vpc.yaml` template.
	 
     Consider reusing an existing one if it's set up with a NAT gateway or an EC2 endpoint, which are expensive and wouldn't be worth creating for these purposes but which could be advantageous. It might also be a good idea if the vibes builds are to be consumed by an application or service of yours.

 2.  Deploy a new CloudFormation stack based on the `ec2/cfn.yaml` template.

 3.  Create the necessary EC2 key pairs.

     Firstly, create the key pair used for the build instances. The private key must be made available in the parameter store for the build projects to retrieve it.
	 
	      $  aws --query 'KeyMaterial' --output text ec2 create-key-pair --key-name vibes-builds > ~/.ssh/vibes-builds.pem
		  $  chmod 0600 ~/.ssh/vibes-builds.pem
	      $  aws ssm put-parameter --name /vibes/ec2/keys/builds --type SecureString --value "file://${HOME}/.ssh/vibes-builds.pem"
	 
     Then, create the key pairs for the actual instances.
	 
	      $  for NAME in worker server ; do aws --query 'KeyMaterial' --output text ec2 create-key-pair --key-name vibes-${NAME} > ~/.ssh/vibes-${NAME}.pem && chmod 0600 ~/.ssh/vibes-${NAME}.pem ; done
	 
     Those commands will get you the private keys and store them with appropriate permissions.

 4.  Set up the VPC.

     For instance, you might want to start your SSH bridge –commonly known as “bastion host”– or your NAT instance.

 5.  Build the AMIs.

     Thanks to Packer, this is a fully automated process. We just have to start a build of the relevant CodeBuild projects.
     
     Let `PROJECT` be each of `volmgr`, `worker` and `server`, then start a build of the CodeBuild project:
     
         $  BUILD_ID=$(aws --query 'build.id' --output text codebuild start-build --project-name vibes-ec2-ami-$PROJECT)
     
     To retrieve the logs, you can use:
     
         $  aws --query 'events[*].message' --output text logs get-log-events --log-group-name /aws/codebuild/vibes-ec2-ami-$PROJECT --log-stream-name "$(aws --query 'builds[0].logs.streamName' --output text codebuild batch-get-builds --ids "$BUILD_ID")" | sed -e 's/^[ \t]*\(\[Container\][ \t]*\)\?//'
     
     Or just visit the web console.

 6.  Create the volumes.

     Due to a Packer bug, this had to be automated by hand –if that makes any sense–, but that should be transparent to the user, who must merely start a couple of CodeBuild builds.
	  
	     $  aws codebuild start-build --project-name vibes-ec2-ebs-sources
		 $  aws codebuild start-build --project-name vibes-ec2-ebs-builds
	  
	 That should get you going.
	 
	 The creation of the sources volume may take long, depending on the instance type you choose to perform the task and on your VPC configuration. Among other factors, the type of your NAT instance, if you have one, makes a difference.

 7.  Compile the library.

     1.  Launch a worker instance.
     
         You can use the launch template:
         
             $  WORKER_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=vibes-worker)
         
         Choose an instance type with good compute power.
     
     2.  Connect to the instance.
     
         First things first:
         
             $  WORKER_INSTANCE_IP=$(aws --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text ec2 describe-instances --instance-ids $WORKER_INSTANCE_ID)
     
     3.  Start a tup build.
     
         Remember to perform this task as the `vibes` user!
		   
		     #  su vibes
			 $  cd /var/opt/vibes/work
			 $  tup todo
         
         With that last command, you will get to know which are the next steps. The almighty tup might ask you to parse the files.
         
			 $  tup parse
			 $  tup todo
			 $  echo 'Great!'
         
         Building your entire collection may take some time.
     
     4.  Unmount the builds volume.
     
         This should flush anything that hasn't been written yet.
         
             #  umount -- /mnt/vibes/builds
         
         Now it should be safe to create a snapshot of the volume.
     
     5.  Stop the instance.
     
     6.  Update the builds volume snapshot.
     
         This should flush anything that hasn't been written yet.
         
             $  aws ec2 create-snapshot
         
         Optionally, you can delete the old snapshot:
         
			 $  aws ec2 delete-snapshot
         
         Now on to the most exciting part.
     
     7.  Terminate the instance.
     
         This will also delete the volumes.

 8.  Get your music.

     1.  Launch a server instance.
     
         You can use the launch template:
          
             $  SERVER_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-server --instance-type t2.micro)
          
         Choose an instance type with good network bandwidth. Barely any compute power is needed.
     
     2.  Attach the builds volume to the instance.


Resources
--------------------------------------------------------------------------------

