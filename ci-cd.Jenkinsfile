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

    }
    stages {
        stage('get public IP') {
            steps {
                script{
                  sh """
                     aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query Reservations[0].Instances[0].NetworkInterfaces[0].PrivateIpAddresses[0].Association.PublicIp > publicip1.txt; \
                     aws ec2 describe-instances --filters Name=instance-state-name,Values=running --query Reservations[1].Instances[0].NetworkInterfaces[0].PrivateIpAddresses[0].Association.PublicIp > publicip2.txt; \
                     export PUBLIC_IP1=\$(cut -d '"' -f 2 publicip1.txt); \
                     export PUBLIC_IP2=\$(cut -d '"' -f 2 publicip2.txt); \
                     sed -i "s/server1/\$PUBLIC_IP1/g" /Users/mac/.jenkins/workspace/ci-cd-petclinic/host.txt; \
                     sed -i "s/server2/\$PUBLIC_IP2/g" /Users/mac/.jenkins/workspace/ci-cd-petclinic/host.txt; \
                     cat /Users/mac/.jenkins/workspace/ci-cd-petclinic/host.txt;
                     """
                }
            }
        }
    stages {
        stage('triger ansible') {
            steps {
                script{
                  sh "ansible-playbook -i host.txt playbook.yaml"
                }
            }
        }
    }
}
