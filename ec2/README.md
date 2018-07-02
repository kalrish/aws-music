EC2 implementation
================================================================================

This implementation is based on EC2 and provides much more flexibility, albeit with greater complexity, than the CodeBuild one. It comprises a VPC with a private and a public subnet, two EBS volumes to contain a copy of the sources and the compressed files, respectively, and various instances performing different tasks. The output is made available through servers via a variety of protocols.


Deployment
--------------------------------------------------------------------------------

  1.  Deploy a new CloudFormation stack based on the `ec2/cfn.yaml` template.
 
  2.  Create the necessary EC2 key pairs.
  
      Firstly, create the key pair used for the build instances. The private key must be made available in the parameter store for the build projects to retrieve it.
	  
	      $  aws --query 'KeyMaterial' --output text ec2 create-key-pair --key-name vibes-builds > ~/.ssh/vibes-builds.pem
		  $  chmod 0600 ~/.ssh/vibes-builds.pem
	      $  aws ssm put-parameter --name /vibes/ec2/keys/builds --type SecureString --value "file://${HOME}/.ssh/vibes-builds.pem"
	  
      Then, create the key pairs for the actual instances.
	  
	      $  for NAME in worker server ; do aws --query 'KeyMaterial' --output text ec2 create-key-pair --key-name vibes-${NAME} > ~/.ssh/vibes-${NAME}.pem && chmod 0600 ~/.ssh/vibes-${NAME}.pem ; done
 
  3.  Build the AMIs.
 
      Thanks to Packer, this is a fully automated process. We just have to start a build of the relevant CodeBuild projects.
      
      Let `PROJECT` be each of `music-volmgr-ami`, `music-worker-ami` and `music-server-ami`, then start a build of the CodeBuild project:
      
          $  BUILD_ID=$(aws --query 'build.id' --output text codebuild start-build --project-name $PROJECT)
      
      To retrieve the logs, you can use:
      
          $  aws --query 'events[*].message' --output text logs get-log-events --log-group-name /aws/codebuild/$PROJECT --log-stream-name "$(aws --query 'builds[0].logs.streamName' --output text codebuild batch-get-builds --ids "$BUILD_ID")" | sed -e 's/^[ \t]*\(\[Container\][ \t]*\)\?//'
 
  4.  Start the SSH bridge.
 
      Except for the server, all instances reside within a private subnet. Therefore, it is possible to connect to them only through a so-called bastion server.
      
          $  BRIDGE_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-volmgr --instance-type t2.micro)
      
      Since the bridge instance doesn't have to do any real processing, you're free to choose the cheapest instance type.
 
  5.  Create the volumes.
 
       1.  Create EBS volumes of appropriate size to hold the music sources and the build artifacts, respectively.
      
           We will save the ID of the volumes.
           
               $  AVAILABILITY_ZONE=$(aws --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text ec2 describe-instances --instance-ids $VOLMGR_INSTANCE_ID)
               $  SOURCES_VOLUME_ID=$(aws --query 'VolumeId' --output text ec2 create-volume --availability-zone $AVAILABILITY_ZONE --size $SIZE --tag-specifications 'ResourceType=volume,Tags=[{Key=music,Value=sources}]' $ANY_OTHER_OPTIONS)
               $  BUILDS_VOLUME_ID=$( aws --query 'VolumeId' --output text ec2 create-volume --availability-zone $AVAILABILITY_ZONE --size $SIZE --tag-specifications 'ResourceType=volume,Tags=[{Key=music,Value=builds}]' $ANY_OTHER_OPTIONS )
      
       2.  Launch an EC2 instance based on the volume manager AMI.
      
           You can use the launch template:
           
               $  VOLMGR_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-volmgr --instance-type t2.micro)
           
           Since the instance will be used to download the entire music sources into the volume, which might take a long time, you should pick a cheap instance type with good network bandwidth.
      
       3.  Attach the volumes to the instance.
           
               $  aws ec2 attach-volume --volume-id $SOURCES_VOLUME_ID --instance-id $VOLMGR_INSTANCE_ID --device /dev/xvdf
               $  aws ec2 attach-volume --volume-id $BUILDS_VOLUME_ID  --instance-id $VOLMGR_INSTANCE_ID --device /dev/xvdg
      
       4.  Connect to the instance.
      
           First things first:
           
               $  BRIDGE_INSTANCE_IP=$(aws --query 'Reservations[0].Instances[0].PublicIpAddress' --output text ec2 describe-instances --instance-ids $BRIDGE_INSTANCE_ID)
               $  VOLMGR_INSTANCE_IP=$(aws --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text ec2 describe-instances --instance-ids $VOLMGR_INSTANCE_ID)
           
           There are two ways to go about this.
           
           -  If your SSH client supports ProxyCommand, use that.
           
           -  If not:
           
               1.  Copy the volume manager's private key to the bridge. I know this is terrible, but your SSH implementation is even worse by not supporting ProxyCommand.
               
                       $  scp -i ~/.ssh/music-bridge.pem ~/.ssh/music-volmgr.pem ${USERNAME}@${BRIDGE_INSTANCE_IP}:/music-volmgr.pem
               
               2.  Connect to the bridge.
               
                       $  ssh -i ~/.ssh/music-bridge.pem ${USERNAME}@${BRIDGE_INSTANCE_IP}
               
               3.  Connect to the volume manager from the bridge.
               
                       $  ssh -i /music-volmgr.pem root@${VOLMGR_INSTANCE_IP}
      
       5.  Format the volumes with the filesystems of your choice.
      
           Pay attention to the device names, which might be different than the ones we specified when attaching the volumes to the instance.
           
               $  mke2fs -t ext4 /dev/xvdf
               $  mke2fs -t ext4 /dev/xvdg
      
       6.  Mount the filesystems.
      
               $  mount -t ext4 /dev/xvdf /mnt/music/sources
               $  mount -t ext4 /dev/xvdg /mnt/music/builds
      
       7.  Prepare the volumes.
      
           The worker and server systems expect a certain directory hierarchy on the volumes. The volume manager AMI contains scripts to prepare.
           
               $  music-prepare_volume-sources /mnt/music/sources
               $  music-prepare_volume-builds  /mnt/music/builds
      
       8.  Download the music sources into the sources volume.
      
               $  aws s3 cp --recursive "s3://$(cat /usr/local/share/music/sources_bucket)" /mnt/music/sources
           
           Should the command fail part-way, you can restart the process where it was left:
           
               $  aws s3 sync "s3://$(cat /usr/local/share/music/sources_bucket)" /mnt
      
       9.  Unmount the volumes.
      
               $  umount /mnt/music/{sources,builds}
      
      10.  Detach the volumes.
      
               $  aws ec2 detach-volume --volume-id $SOURCES_VOLUME_ID
               $  aws ec2 detach-volume --volume-id $BUILDS_VOLUME_ID
      
      11.  Terminate the instance.
      
           The launch template is configured so that the instance is terminated on OS-initiated shutdown, so you don't have to terminate it manually through the API.
           
               $  systemctl poweroff
               $  exit
           
           Bonus points if you manage to sneak the `exit`.
      
      12.  Create a snapshot of the volume.
      
           You won't be compiling your music collection too often, so it might be a good idea to delete the sources volume when you're done to save on costs. However, you won't want to re-download your collection, so the in-the-middle solution is to create a snapshot of it.
      
               $  SOURCES_SNAPSHOT_ID=$(aws --query 'SnapshotId' --output text ec2 create-snapshot --volume-id $SOURCES_VOLUME_ID --tag-specifications 'ResourceType=snapshot,Tags=[{Key=music,Value=sources}]')
           
           Then, you can re-create the sources volume any time you want without having to pay for an EBS volume.
 
  6.  Compile the music library.
 
      1.  Launch a worker instance.
      
           You can use the launch template:
           
               $  WORKER_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-worker --instance-type t2.micro)
           
           Choose an instance type with good compute power.
      
      2.  Attach the sources and builds volumes to the instance.
      
      3.  Connect to the instance.
      
           First things first:
           
               $  WORKER_INSTANCE_IP=$(aws --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text ec2 describe-instances --instance-ids $WORKER_INSTANCE_ID)
      
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
 
  7.  Spin up the server.
 
      1.  Launch a server instance.
      
           You can use the launch template:
           
               $  SERVER_INSTANCE_ID=$(aws --output text --query 'Instances[*].InstanceId' ec2 run-instances --launch-template LaunchTemplateName=music-server --instance-type t2.micro)
           
           Choose an instance type with good network bandwidth. Barely any compute power is needed.
      
      2.  Attach the builds volume to the instance.
      
 8.  er


Resources
--------------------------------------------------------------------------------

###  AMIs

| AMI name       | Contents
| -------------- | ----------
| music-volmgr   |
| music-worker   |
| music-server   |

####  Volume manager
The volume manager AMI contains the tools required to manage the filesystems supported by Arch as well as the AWS CLI, which is used to download the music sources from the S3 bucket.

####  Worker
The worker AMI contains tup, the build system used to orchestrate the build process, the encoders supported by the build code and the tools required to mount the filesystems.

####  Server
The server AMI contains rsync as.
