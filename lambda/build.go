package main

import (
    "github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go"
)

func build () (string, error) {
	client := ec2.New(session.New())
	
	rv, err := client.RunInstances(
		&ec2.RunInstancesInput{
			LaunchTemplate: &ec2.LaunchTemplateSpecification{
				LaunchTemplateName: "vibes-worker",
			},
			MinCount: 1,
			MaxCount: 1,
		},
	)
	
    return "Hello ƛ!", nil
}

func main () {
    lambda.Start(build)
}
