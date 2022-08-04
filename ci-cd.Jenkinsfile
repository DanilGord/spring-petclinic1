pipeline {
    agent any
    environment {
        AWS_DEFAULT_REGION="eu-north-1"
        THE_BUTLER_SAY_SO=credentials('aws-secrets')
    }

    stages {
        stage('build') {
            steps {
                script{
                  sh "./mvnw package"
                }
            }
        }
        stage('get public IP') {
            steps {
                script{
                  sh """
                     export PUBLIC_IP1=\$(/usr/local/bin/aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].[PublicIpAddress]' --output text); \
                     export PUBLIC_IP2=\$(/usr/local/bin/aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].[PublicIpAddress]' --output text); \
                     sed -i "s/server1/\$PUBLIC_IP1/g" /Users/mac/.jenkins/workspace/ci-cd-petclinic/host.txt; \
                     sed -i "s/server2/\$PUBLIC_IP2/g" /Users/mac/.jenkins/workspace/ci-cd-petclinic/host.txt; \
                     cat /Users/mac/.jenkins/workspace/ci-cd-petclinic/host.txt;
                     """
                }
            }
        }
        stage('triger ansible') {
            steps {
                script{
                  sh "ansible-playbook -i host.txt playbook.yaml"
                }
            }
        }
    }
}
