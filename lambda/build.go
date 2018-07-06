package main

import (
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/ssm"
	"golang.org/x/crypto/ssh"
	"io"
	"log"
	"net"
	"os"
	"time"
)

func build() (string, error) {
	client_ec2 := ec2.New(session.New())

	rv_ec2_RunInstances, err := client_ec2.RunInstances(
		&ec2.RunInstancesInput{
			InstanceType: aws.String("t2.micro"),
			LaunchTemplate: &ec2.LaunchTemplateSpecification{
				LaunchTemplateName: aws.String("vibes-worker"),
			},
			MaxCount: aws.Int64(1),
			MinCount: aws.Int64(1),
			TagSpecifications: []*ec2.TagSpecification{
				{
					ResourceType: aws.String("instance"),
					Tags: []*ec2.Tag{
						{
							Key: aws.String("Manager"),
							Value: aws.String("vibes-lambda-build"),
						},
					},
				},
			},
		},
	)

	if err == nil {
		log.Println("Successfully launched worker instance")

		instance_id := aws.StringValue(rv_ec2_RunInstances.Instances[0].InstanceId)

		log.Println("Worker instance ID: ", instance_id)

		client_ssm := ssm.New(session.New())

		rv_ssm_GetParameter, err := client_ssm.GetParameter(
			&ssm.GetParameterInput{
				Name:           aws.String("/vibes/keys/worker"),
				WithDecryption: aws.Bool(true),
			},
		)

		ssh_key, err := ssh.ParsePrivateKey([]byte(aws.StringValue(rv_ssm_GetParameter.Parameter.Value)))
		if err == nil {
			ssh_config := &ssh.ClientConfig{
				User: "root",
				Auth: []ssh.AuthMethod{
					ssh.PublicKeys(ssh_key),
				},
			}

			err := client_ec2.WaitUntilInstanceRunning(
				&ec2.DescribeInstancesInput{
					InstanceIds: []*string{
						&instance_id,
					},
				},
			)

			instance_ip_address := aws.StringValue(rv_ec2_RunInstances.Instances[0].PrivateIpAddress)

			ssh_port := "22"

			for {
				connection, _ := net.DialTimeout("tcp", net.JoinHostPort(instance_ip_address, ssh_port), time.Second)
				if connection != nil {
					connection.Close()
					break
				}
			}

			ssh_connection, err := ssh.Dial("tcp", net.JoinHostPort(instance_ip_address, ssh_port), ssh_config)
			if err == nil {
				ssh_session, err := ssh_connection.NewSession()
				if err == nil {
					modes := ssh.TerminalModes{
						ssh.ECHO:          0,
						ssh.TTY_OP_ISPEED: 14400,
						ssh.TTY_OP_OSPEED: 14400,
					}

					err := ssh_session.RequestPty("xterm", 80, 40, modes)
					if err == nil {
						stdin, err := ssh_session.StdinPipe()
						go io.Copy(stdin, os.Stdin)

						stdout, err := ssh_session.StdoutPipe()
						go io.Copy(os.Stdout, stdout)

						stderr, err := ssh_session.StderrPipe()
						go io.Copy(os.Stderr, stderr)

						err = ssh_session.Run("ls -l /var/opt/vibes")
						if err == nil {
						}
					}

					ssh_session.Close()
				}
			}
		}

		rv_ec2_TerminateInstances, err := client_ec2.TerminateInstances(
			&ec2.TerminateInstancesInput{
				InstanceIds: []*string{
					&instance_id,
				},
			},
		)

		_ = rv_ec2_TerminateInstances

		return "Hello ƛ!", nil
	} else {
		log.Println("Could not launch worker instance")

		return "FAIL", err
	}
}

func main() {
	lambda.Start(build)
}
