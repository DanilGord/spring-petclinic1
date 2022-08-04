pipeline {
    agent any
    tools{
        terraform 'terraform'
    }
    environment {
        AWS_DEFAULT_REGION="eu-north-1"
        THE_BUTLER_SAY_SO=credentials('aws-secrets')
    }
    stages {
        stage('terraform up') {
            steps {
                script{
                  sh "pwd"
                  sh "terraform init"
                  sh "terraform apply --auto-approve"
                }
            }
        }

    }
}
