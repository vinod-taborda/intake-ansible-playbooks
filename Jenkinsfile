node {
    ws {
        checkout scm
        echo "${IMAGE_TAG}"
         
        withEnv(["AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}", 
            "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}", 
            "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}",
            "DOCKER_EMAIL=${DOCKER_EMAIL}"
            ]) {
            
            withCredentials([
                [$class: 'FileBinding', credentialsId: 'ssh_private_key', variable: 'KEY_FILE'],
                [$class: 'UsernamePasswordMultiBinding', credentialsId: 'docker_credentials',
                            usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASSWORD']
            ]) {
                sh 'ansible-galaxy install -p ./roles dochang.docker'
                sh 'ansible-galaxy install -p ./roles Datadog.datadog'
                sh 'echo "${HOSTS}" > ./hosts'
                sh 'echo "${GROUP_VARS}" > ./group_vars/all'
                sh 'ansible-playbook -u ec2-user -i ./hosts --key-file=$KEY_FILE --skip-tags=local_dependencies --extra-vars="intake_image_tag=${IMAGE_TAG} username=$DOCKER_USER email=$DOCKER_EMAIL password=$DOCKER_PASSWORD" config-docker-intake-node.yml'
            }
        }
    }
}
