CodeBuild implementation
================================================================================

This implementation, based on CodeBuild, is targeted at small libraries. It will download the sources into the build container, encode them after the specified profile and then upload the artifacts to a bucket. Effort has been put to avoid that sources which have already been encoded are not processed again, but it cannot be achieved; tup is too smart. Therefore, there are no incremental builds, which will hurt when you start adding albums to your collection.


Deployment
--------------------------------------------------------------------------------

 1.  Deploy a new CloudFormation stack based on the `env/cfn.yaml` template.
 
 2.  Build the CodeBuild environment.
 
     Start a build of the `vibes-codebuild-env` project:
     
         $  aws codebuild start-build --project-name vibes-codebuild-env
     
     If the build finishes correctly, the `vibes-codebuild-env` ECS repository should have a container image ready to be used by the run jobs.
 
 3.  For each profile, deploy a new CloudFormation stack based on the `run/cfn.yaml` template.
 
 4.  Encoded the library after the various profiles.
