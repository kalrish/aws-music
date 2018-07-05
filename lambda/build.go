package main

import (
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
)

func build () (string, error) {
	client := ec2.New(session.New())

	rv, err := client.RunInstances(
		&ec2.RunInstancesInput{
			LaunchTemplate: &ec2.LaunchTemplateSpecification{
				LaunchTemplateName: aws.String("vibes-worker"),
			},
			MinCount: aws.Int64(1),
			MaxCount: aws.Int64(1),
		},
	)

	return "Hello ƛ!", nil
}

func main () {
	lambda.Start(build)
}
