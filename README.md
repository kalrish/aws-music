#  AWS-based music compilation system


##  Deployment

  1.  Clone this repository.
 
          $  git clone https://github.com/kalrish/aws-music.git
 
  2.  Deploy a new CloudFormation stack based on `cfn/main.yaml`.
 
  3.  Deploy a new CloudFormation stack based on `ec2/cfn.yaml`.
 
  4.  Push the code to your newly-created repository.
 
      From within your clone directory:
      
          $  git remote add codecommit ssh://git-codecommit.eu-central-1.amazonaws.com/v1/repos/music
          $  git remote add codecommit https://git-codecommit.eu-central-1.amazonaws.com/v1/repos/music
          $  git push codecommit master
  
      You might need to configure git or the SSH client. If need be, refer to the official AWS docs.
 
  5.  Upload your music sources to the source bucket.
 
          $  aws s3 sync /path/to/music/sources "s3://$(aws --query 'Parameter.Value' --output text ssm get-parameter --name /music/sources)"
 
  6.  Create the necessary EC2 keypairs.
 
  7.  Build the AMIs.
 
      Thanks to Packer, this is a fully automated process. We just have to start a build of the relevant CodeBuild projects.
      
      Let `PROJECT` be each of `music-volmgr-ami`, `music-worker-ami` and `music-server-ami`, then start a build of the CodeBuild project:
      
          $  BUILD_ID=$(aws --query 'build.id' --output text codebuild start-build --project-name $PROJECT)
      
      To retrieve the logs, you can use:
      
          $  aws --query 'events[*].message' --output text logs get-log-events --log-group-name /aws/codebuild/$PROJECT --log-stream-name "$(aws --query 'builds[0].logs.streamName' --output text codebuild batch-get-builds --ids "$BUILD_ID")" | sed -e 's/^[ \t]*\(\[Container\][ \t]*\)\?//'
 
  8.  Start the SSH bridge.
 
      Except for the server, all instances reside within a private subnet. Therefore, it is possible to connect to them only through a so-called bastion server.
      
          $  BRIDGE_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-volmgr --instance-type t2.micro)
      
      Since the bridge instance doesn't have to do any real processing, you're free to choose the cheapest instance type.
 
  9.  Create the sources volume:
 
       1.  Create an EBS volume of appropriate size.
      
           We will save the ID of the volume.
           
               $  SOURCES_VOLUME_ID=$(aws --query 'VolumeId' --output text ec2 create-volume --availability-zone $AVAILABILITY_ZONE $ANY_OTHER_OPTIONS)
      
       2.  Launch an EC2 instance based on the volume manager AMI.
      
           You can use the launch template:
           
               $  VOLMGR_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-volmgr --instance-type t2.micro)
           
           Since the instance will be used to download the entire music sources into the volume, which might take a long time, you should pick a cheap instance type.
      
       3.  Attach the volume to the instance.
      
           With the following command:
           
               $  aws ec2 attach-volume --volume-id $SOURCES_VOLUME_ID --instance-id $VOLMGR_INSTANCE_ID --device /dev/xvdf
      
       4.  Connect into the instance through the SSH bridge.
      
           First we connect to the bridge. The username depends on the distro that the bridge AMI is based on.
           
               $  ssh -i ~/.ssh/bridge.pem ${USERNAME}@$(aws --query 'Reservations[0].Instances[0].PublicIpAddress' --output text ec2 describe-instances --instance-ids $BRIDGE_INSTANCE_ID)
           
           Then, from within the SSH session:
           
               $  ssh -i ~/.ssh/music-volmgr.pem root@$(aws --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text ec2 describe-instances --instance-ids $VOLMGR_INSTANCE_ID)
           
           You might have to configure your SSH client beforehand. Refer to your SSH client's documentation on how to enable agent forwarding.
      
       6.  Format the volume with the filesystem of your choice.
      
           Pay attention to the device name, which might be different than the one we specified when attaching the volume to the instance.
           
               $  mke2fs -t ext4 /dev/xvdf
      
       7.  Mount the filesystem.
      
               $  mount -t ext4 /dev/xvdf /mnt
      
       8.  Download the music sources into the volume.
      
               $  aws s3 sync "s3://$(aws --query 'Parameter.Value' --output text ssm get-parameter --name /music/sources)" /mnt
      
       9.  Unmount the filesystem.
      
               $  umount /mnt
      
      10.  Detach the volume.
      
               $  aws ec2 detach-volume --volume-id $SOURCES_VOLUME_ID
      
      11.  Terminate the instance.
      
           First exit the SSH session to close the connection. Then, terminate the instance:
           
               $  aws ec2 terminate-instances --ids $VOLMGR_INSTANCE_ID
      
      12.  Create a snapshot of the volume.
      
           You won't be compiling your music collection too often, so it might be a good idea to delete the sources volume when you're done to save on costs. However, you won't want to re-download your collection, so the in-the-middle solution is to create a snapshot of it.
      
               $  SOURCES_SNAPSHOT_ID=$(aws --query 'SnapshotId' --output text ec2 create-snapshot --volume-id $SOURCES_VOLUME_ID --tag-specifications 'ResourceType=snapshot,Tags=[{Key=music,Value=sources}]')
           
           Then, you can re-create the sources volume any time you want without having to pay for an EBS volume.
  
 10.  Deploy a new CloudFormation stack based on `cfn/profile.yaml` for each music profile.
 
 11.  Upload the settings for each profile to the relevant SSM parameters.
 
      Use the CLI for this, because tup.config files contain relevant newlines.
      
          $  for PROFILE in flac phone car ; do aws ssm put-parameter --overwrite "/music/profiles/${PROFILE}/config" --type String --value "file://${PROFILE}.config" ; done
 
 12.  Compile the music library.
 
      1.  Launch a worker instance.
      
           You can use the launch template:
           
               $  WORKER_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-worker --instance-type t2.micro)
           
           Choose an instance type with good compute power.
      
      2.  Attach the sources and builds volumes to the instance.
      
      3.  Mount the sources volume.
      
          You can make use of some mount options for increased security and performance.
          
              $  mount -t ext4 -o nodev,noexec,nosuid,data=writeback,noatime /dev/xvdf /mnt/music/sources
      
      4.  Mount the builds volume.
      
          You can make use of some mount options for increased security and performance.
          
              $  mount -t ext4 -o noexec,nosuid,data=writeback,noatime /dev/xvdf /mnt/music/sources
          
          dfd.
      
      5.  Start a tup build.
      
          You can do this in one of two ways:
          
          -  Manually:
          
              This allows you to customize.
              
                  $  cd /var/opt/music/work
                  $  sudo -u music tup
          
          -  Making use of the systemd oneshot service provided:
          
              It is already configured.
              
                  $  systemctl enable music-build.service
              
              To see the logs:
              
                  $  journalctl -u music-build.service
          
          This will take some time.
      
      6.  Stop or terminate the instance.
 
 13.  Spin up the server.
 
      1.  Launch a server instance.
      
           You can use the launch template:
           
               $  SERVER_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-server --instance-type t2.micro)
           
           Choose an instance type with good network bandwidth. Barely any compute power is needed.
      
      2.  Attach the builds volume to the instance.
      
 14.  er
