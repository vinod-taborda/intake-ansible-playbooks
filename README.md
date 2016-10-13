# Accelerator Playbooks
This is an initial version of the ansible playbooks meant to accelerate development of the Intake Accelerator and Jenkins pipelines that automate the ansible playbooks. You will find a mixture of provisioning, configuration, and management of Docker hosts. 


## Relevant Files:

### These are the main playbooks that launch the services:

`config-docker-api-node.yml` 
`config-docker-intake-node.yml` 
`config-logging-node.yml`

### These playbooks are called by the playbooks above:

`deploy-docker-api.yml` 
`deploy-docker-intake.yml` 
`deploy-docker-log.yml` 

### These jinja2 templates are used by the playbooks above this:

`docker-compose.api.yml.j2` 
`docker-compose.intake.yml.j2` 
`docker-compose.log.yml.j2` 

### These Jenkins files are used by Jenkins for building a pipeline

`Jenkinsfile`
`Jenkinsfile.api`

### Variables:

`group_vars/all` This file contains variables that all playbooks will use. Currently:
 ```
elasticsearch_log_server: <INSERT_IP_OR_SERVER_NAME> 
intake_image_tag: <INSERT_IMAGE_TAG_HERE>
api_image_tag: <INSERT_IMAGE_TAG_HERE>
api_url: <INSERT_API_URL>
intake_elasticsearch_url: <INSERT_INTAKE_ELASTICSEARCH_URL>
 ```

### Other Misc Files:

`bin/add-remote-ec2-sshkey`  Utility script to copy the ssh key to a specified remote host

`nginx/` nginx-specific config

`roles/`  Empty directory used by Ansible

`99-docker.conf.j2`  Configuration file for docker logging

`README.md` The contents of this file

`add-datadog-agent.yml`  Ansible script to add DataDog to the current server

`cleanup.yml`  Ansible script that performs a cleanup of the `./tmp/`

`config-jenkins-nodes.yml` Ansible script to configure Jenkins node and install Jenkins

`deploy-jenkins.yml`  Ansible script called by `config-jenkins-nodes.yml` to deploy Jenkins in Docker container

`docker-compose.jenkins.yml.j2` jinja2 template of the docker compose file used to compose the docker containers needed for Jenkins

`hosts`  Here you configure the hosts that Ansible will run playbooks against.

`hosts.sample` This is a template of the Ansible `hosts` file.

`rsyslog.conf.j2` rsyslog configuration template. 

`tmp/` This file will be created and then destroyed (will contain secrets for SSL and AWS S3).

# Deployment

There are three ways to deploy: All manual, build manual and deploy from Jenkins, and all from Jenkins.

Note 1: All manual sections assume that you will be ssh'ing to the current ansible control host.

Note 2: The gray highlights are the code you will be copying.

## Manually building the `intake_accelerator` and `intake_api_prototype` docker images
This section describes the manual build process for developers.

**PREREQUESITE** Make sure docker-machine is working and you're able to do `docker ps`.

Starting with intake_accelerator as `<REPO NAME>`, perform the following steps:

1. `git clone git@github.com:ca-cwds/<REPO NAME>.git`
2. `cd <REPO NAME>`
3. `git checkout master`
4. `git pull --rebase`
5. `docker build -f Dockerfile.production -t ca-cwds/<REPO NAME>:$(git rev-parse --short HEAD) . `
   (Note: If you encounter warning messages, ignore. All you want is your last line to say `Successfully built ...`)
6. `docker push ca-cwds/<REPO NAME>:$(git rev-parse --short HEAD)` to docker hub
7. `cd ..` and repeat the above steps for `intake_api_prototype` as `<REPO NAME>`

## Creating an Ansible Control Host.

If you are setting up the infrastructure for the first time, you will need to provision a server to act as the Ansible control host.   Start from a VM with Linux (e.g. Ubuntu is fine).


1. Install dependencies:
  ```
  sudo yum update -y
  sudo yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 
  sudo yum -y install ansible-2.1.1.0 
  sudo yum -y install git
  sudo yum -y install python-pip 
  sudo pip install awscli

  sudo ansible-galaxy install dochang.docker
  sudo ansible-galaxy install Datadog.datadog
  ```

2. You will need a S3 bucket on AWS to store secrets. If you do not have one already, perform the following steps: 
  - Create an S3 bucket for storing secrets (call it `accelerator-s3-secrets`)
  - Upload all the secret files to S3. You will need the following:
    1. `nginx.crt`
    2. `nginx.key`
    3. `dd-agent.key`
  - Create an IAM group with read-only permissions to your S3 bucket
  - Create an IAM user and place it into the IAM group created above

3. Configure AWS with credentials that can read the secrets bucket:
   ```
   sudo aws configure
   ```

   You will be prompted for: 
   - `AWS Access Key ID`
   - `AWS Secret Access Key` 
   - `Default region name [us-east-1]:` (us-east-1 is just an example. Note that there is no trailing letter, such as `us-east-1c`)
   - `Default output format [None]:`  (This can be left blank or enter `json` which is the default output format)

4. Verify AWS access to credentials bucket:
   `sudo aws s3 ls` (This should not result in an error, but a list of objects if there are any.)

5. On your Ansible host, create new ssh keys. All you will need is the public key.
   Run command `ssh-keygen`, taking all the defaults by hitting <enter> until you get back your command prompt. Note: If using AWS, use the key pair selected when creating new instances in EC2 (instead of creating a new key pair) and copy the private key (currently CWDS_rsa) to the .ssh directory on the Ansible host.

6. Copy your Ansible hosts public key (*.pub) to all client machines that will be managed by Ansible into file `/$USER/.ssh/authorized_keys`. Note: If using AWS, this step does not need to be performed on any machines which were created using the CWDS_rsa key.

7. Upload the private key created in step 5 into the Jenkins Credentials as a Secret file with the ID set to ssh_private_key. Note: The ID is used in Jenkinsfile and Jenkinsfile.api.

8. git clone this repo. `git clone https://github.com/Casecommons/accelerator-playbooks.git`

9. `cd accelerator-playbooks`

10. Create an inventory file: `cp ./hosts.sample ./hosts`

11. In the `hosts` file, under `[logging-node]` and `[api-node]` and `[intake-node]`, insert the clients that will be managed by Ansible (one ip address or hostname per line). 

12. Create a vars file:`cp ./group_vars/all.sample ./group_vars/all`

13. Now update the `./group_vars/all` file (Note: `intake_elasticsearch_url` and `elasticsearch_log_server` should point to the private IP on AWS. `intake_elasticsearch_url` specifically, is a tempoary solution until we figure out how search will be implemented with the partner): 
    ```
    vi ./group_vars/all`
    ```
    ```
    elasticsearch_log_server: <INSERT_IP_ADDR_OR_HOSTNAME> 
    intake_image_tag: <INSERT_IMAGE_TAG>
    api_image_tag: <INSERT_IMAGE_TAG>
    api_url: <INSERT_API_URL>
    intake_elasticsearch_url: <INSERT_INTAKE_ELASTICSEARCH_URL>
    ```
How do I find the image tag?
   - intake_image_tag from [here](https://hub.docker.com/r/casecommons/intake_accelerator/tags/)
   - api_image_tag from [here](https://hub.docker.com/r/casecommons/intake_api_prototype/tags/)

14. Verify that the Ansible host can talk to the client:
  ```
   ansible -i ./hosts intake-node -m ping
   ansible -i ./hosts api-node -m ping
   ansible -i ./hosts logging-node -m ping
  ```
  You should see a success message.
15. Follow the deploy section below


## Manually Deploying

1. SSH into the Ansible Control Host and follow the remaining instructions.
2. `cd  /home/ec2-user/accelerator-playbooks`
3. Edit the `hosts` inventory file to include the hosts (or ip addresses) you want to run playbooks against: 
   ```
   ...
   [logging-node]
   xxx.xxx.xxx.xxx  

   [api-node]
   xxx.xxx.xxx.xxx  

   [intake-node]
   xxx.xxx.xxx.xxx 

   ...
   ```

   (NOTE: If you want to deploy Jenkins, add `[jenkins-node]` and the corresponding IP address to the hosts file.)

4. To verify connectivity between the Ansible control server and the clients: `ansible -i ./hosts all -m ping`
  (Note: All clients should succeed except for the jenkins host)

5. Change directories: `cd  groups_vars`

6. Copy this file: `cp  all.sample  all`

7. Edit this file: `vi  all`  

    ```
    elasticsearch_log_server: <INSERT_IP_OR_SERVER_NAME>
    intake_image_tag: <INSERT_IMAGE_TAG_HERE>
    api_image_tag: <INSERT_IMAGE_TAG_HERE>
    api_url: <INSERT_API_URL>
    intake_elasticsearch_url: <INSERT_INTAKE_ELASTICSEARCH_URL>
    ``` 

8. Now run the following Ansible playbooks:
   ```
    `ansible-playbook -i ./hosts config-logging-node.yml`
    `ansible-playbook -i ./hosts config-docker-api-node.yml` (Note: You'll be prompted for your dockerhub credentials)
    `ansible-playbook -i ./hosts config-docker-intake-node.yml` (Note: You'll be prompted for your dockerhub credentials) 
   ```

 (NOTE: The playbook will prompt you for your dockerhub login, password, and email.)
 (NOTE 2: If you want to deploy Jenkins and have followed the note in step 3, run the following Ansible playbook
 ```
 `ansible-playbook -i ./hosts config-jenkins-nodes.yml` (Note: You'll be prompted for your dockerhub credentials)
 ```

9. If you are on AWS:

- Open your security group to accept incoming traffic from port 80.
- In Elastic IPs
  - Associate the public IP address of the "logging" node with `<logging server domain name>` 
  - Associate the public IP address of the "api" node with `<api server domain name>`
  - Associate the public IP address of the "intake" node with `<intake server domain name>` 

10. To verify that the `logging` server works: 

   - EITHER: `curl <logging server domain name>`
   - OR: Enter `<logging server URL>` into your browser navigation bar.
   - OR: Enter the ip address of the server into your browser navigation bar.

11. To verify that the `api` server works: 

   - EITHER: `curl <api server domain name>` This will return nothing (ie, a blank line with no text).
   - OR: Enter `<api server URL>` into your browser navigation bar. This will return a blank page (100% blank).
   - OR: Enter the ip address of the server into your browser navigation bar.

12. To verify that the `intake` server works: 

   - EITHER: `curl <intake server domain name>`
   - OR: Enter the `<intake server URL>` into your browser navigation bar.
   - OR: Enter the ip address of the server into your browser navigation bar.

14. Test all the links: 

   - `Create Referral`
   - `Create Person`
   - `Referrals`

If this is the first time running the playbook.

1. Verify that datadog is working. Log on to datadog and find your hostname [here](https://app.datadoghq.com/infrastructure)
2. Verify that Rsyslog is picking up. Go to Kibana. Click Discover. Then on the left hand side, click on host to see the hostname.
  

### Re-deploying new images

Assuming you have done an intial deploy like the above, you can deploy individual app/api images like so:

For intake:
```
 ansible-playbook config-docker-intake-node.yml 
```

For api:
```
 ansible-playbook config-docker-api-node.yml 
```

Verify that it works: 

- EITHER: `curl <intake server domain name>`.
- OR:  Enter `<intake server URL>` into your browser navigation bar.  
- OR: Enter the ip address of the server into your browser navigation bar.

Ensure the links all workd. Currently, the links available are: 

- `Create Referral` 
- `Create Person`
- `Referrals`

## Deploying from Jenkins

### Initial Setup

#### Intake

1. Create a new pipeline with a descriptive name (e.g. intake_deploy_to_acceptance)

2. Check the "This project is parameterized" box and set the following parameters:

|Name|Type|Default Value|Description|
|----|----|-------------|-----------|
|AWS_ACCESS_KEY_ID|Password Parameter|`<Access key for AWS>`|This uses the Jenkins user AWS credentials|
|AWS_SECRET_ACCESS_KEY|Password Parameter|`<Secret access key for AWS>`|This uses the Jenkins user AWS credentials|
|AWS_DEFAULT_REGION|String Parameter|`<us-east-1>`||
|HOSTS|Multi-line String Parameter|[ansible-host]<br/>127.0.0.1<br/><br/>[intake-node]<br/><IP of node to host intake>||
|GROUP_VARS|Multi-line String Parameter|elasticsearch_log_server: <IP of elastic search log server (API server for now)><br/>api_url: http://api.mycasebook.org/<br/>intake_elasticsearch_url: <URL of elastic search server (port 9200 of API server for now)>||
|SSH_KEY|Credentials Parameter|`<Credential added to Jenkins with ID of ssh_private_key>`|Note: Credential type is Secret file but is not required|
|DOCKER_CREDENTIALS|Credentials Parameter|`<Credentials that are able to access the casecommons/intake_accelerator images in dockerhub.>`|Note: Credential type is Username with password and is required. Credentials may need to be added to Jenkins credentials|
|DOCKER_EMAIL|String Parameter|`<Email associated with DOCKER_CREDENTIALS>`||
|IMAGE_TAG|String Parameter|casecommons/intake_accelerator:`<Tag name of image to be deployed>`||

3. There are no build triggers or advanced project options

4. Set the pipeline
  - Definition: Pipeline script from SCM
  - SCM: Git
  - Repositories
    - Repository URL: https://github.com/ca-cwds/intake-ansible-playbooks.git
    - Credentials: None
  Branches to build: */master
  Repository browser: (Auto)
  Additional Behaviors: None
  Script Path: Jenkinsfile

#### API

1. Create a new pipeline with a descriptive name (e.g. api_deploy_to_acceptance)

2. Check the "This project is parameterized" box and set the following parameters:

|Name|Type|Default Value|Description|
|----|----|-------------|-----------|
|AWS_ACCESS_KEY_ID|Password Parameter|`<Access key for AWS>`|This uses the Jenkins user AWS credentials|
|AWS_SECRET_ACCESS_KEY|Password Parameter|`<Secret access key for AWS>`|This uses the Jenkins user AWS credentials|
|AWS_DEFAULT_REGION|String Parameter|`<us-east-1>`||
|HOSTS|Multi-line String Parameter|[ansible-host]<br/>127.0.0.1<br/><br/>[api-node]<br/><IP of node to host api>||
|GROUP_VARS|Multi-line String Parameter|elasticsearch_log_server: <Private IP of logging server)>||
|SSH_KEY|Credentials Parameter|`<Credential added to Jenkins with ID of ssh_private_key>`|Note: Credential type is Secret file but is not required|
|DOCKER_CREDENTIALS|Credentials Parameter|`<Credentials that are able to access the casecommons/intake_accelerator images in dockerhub.>`|Note: Credential type is Username with password and is required. Credentials may need to be added to Jenkins credentials|
|DOCKER_EMAIL|String Parameter|`<Email associated with DOCKER_CREDENTIALS>`||
|IMAGE_TAG|String Parameter|casecommons/intake_api_prototype:`<Tag name of image to be deployed>`||

3. There are no build triggers or advanced project options

4. Set the pipeline
  - Definition: Pipeline script from SCM
  - SCM: Git
  - Repositories
    - Repository URL: https://github.com/ca-cwds/intake-ansible-playbooks.git
    - Credentials: None
  Branches to build: */master
  Repository browser: (Auto)
  Additional Behaviors: None
  Script Path: Jenkinsfile.api

### Deployment steps

In Jenkins (https://ci.myhcasebook.org), perform the following steps:

#### Intake

1. Click the intake_deploy_to_acceptance item

2. Click Build with Parameters

3. Verify intake-node (in HOSTS), api_url and intake_elasticsearch_url (in GROUP_VARS), and IMAGE_TAG are correct for this deployment

4. Click Build

#### API

1. Click the api_deploy_to_acceptance item

2. Click Build with Parameters

3. Verify api-node (in HOSTS) and IMAGE_TAG are correct for this deployment

4. Click Build

## Full Build and Deployment from Jenkins

### Initial Setup

1. Create a new pipeline with a descriptive name (e.g. intake(CI))

2. Check GitHub project and set Project url to https://github.com/ca-cwds/intake.git/

2. Check the "This project is parameterized" box and set the following parameters:

|Name|Type|Default Value|Description|
|----|----|-------------|-----------|
|DOCKER_USER|String Parameter|`<Username to use for accessing Docker>`||
|DOCKER_PASSWORD|Password Parameter|`<Password associated to DOCKER_USER`||
|DEPLOY_JOB|String Parameter|intake_deploy_to_acceptance||

3. Check the Build when a change is pushed to GitHub build trigger

4. There are no advanced project options

5. Set the pipeline
  - Definition: Pipeline script from SCM
  - SCM: Git
  - Repositories
    - Repository URL: https://github.com/ca-cwds/intake.git
    - Credentials: None
  Branches to build: */master
  Repository browser: (Auto)
  Additional Behaviors: None
  Script Path: Jenkinsfile
  
Note: For the build to be triggered properly, Jenkins and Github need to be configured such that Github notifies Jenkins of pushes to the specified repository.
  
## Logging

Logging is done with Rsyslog, Kibana, and Elastic search. Rsyslog is pre-installed on each docker host.  Any docker containers will log to the local rsyslog socket. The docker-compose file `docker-compose.log.yml` includes the logging stack as part of this single-node playbook. Feel free to break this up into seperate services when doing multi-node deploys, e.g, kibana on a separate instance.

Alternatively, you can have a Rsyslog container. Just remember to mount the `/dev/log` socket to the host: ` docker run ... -v /dev/log:/dev/log ...`

## License

The Accelerator Playbooks software is free: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

The Accelerator Playbooks software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.

See https://www.gnu.org/licenses/agpl.html

## Copyright

Copyright (c) 2016 Case Commons, Inc.
