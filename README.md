# Accelerator Playbooks
This is an initial version of the ansible playbooks meant to accelerate development of the Intake Accelerator. You will find a mixture of provisioning, configuration, and management of Docker hosts. 


## Relevant Files:

### These are the main playbooks that launch the services:

`config-docker-api-node.yml` 
`config-docker-intake-node.yml` 
`config-logging-node.yml`

### These playbooks are called by the playbooks above:

`deploy-docker-api.yml` 
`deploy-docker-intake.yml` 
`deploy-docker-log.yml` 

### And these jinja2 templates are used by the playbooks above this:

`docker-compose.api.yml.j2` 
`docker-compose.intake.yml.j2` 
`docker-compose.log.yml.j2` 

### Variables:

`group_vars/all` This file contains variables that all playbooks will use. Currently: 
    ```
    elasticsearch_log_server: <INSERT_IP_OR_SERVER_NAME> 
    intake_image_tag: <INSERT_IMAGE_TAG_HERE>
    api_image_tag: <INSERT_IMAGE_TAG_HERE>
    ```

### Other Misc Files:

`hosts`  Here you configure the hosts that Ansible will run playbooks against.

`hosts.sample` This is a template of the Ansible `hosts` file.

`nginx/` nginx-specific config

`README.md` The contents of this file

`rsyslog.conf.j2` rsyslog configuration template. 

`tmp/` This file will be created and then destroyed (will contain secrets for SSL and AWS S3).

`cleanup.yml` This performs a cleanup of the `./tmp/` once it's done. 


# Deployment

The following assumes that you will be ssh'ing to the current ansible control host. Note that the grey highlights are the code you will be copying.

## Building the `ca_intake` and `casebook_api` docker images
This section describes the manual build process for developers.   It will evolve to a more automated build prcess using Jenkins CI.

**FOR MAC USERS** Make sure docker-machine is working and you're able to do `docker ps`.

1. `git clone git@github.com:Casecommons/<INSERT REPO NAME>.git`
2. `cd <INSERT REPO NAME>`
3. `git checkout master`
4. `git pull --rebase`
5. `docker build -f Dockerfile.production -t casecommons/<INSERT REPO NAME>:$(git rev-parse --short HEAD) . `
   (Note: If you encounter warning messages, ignore. All you want is your last line to say `Successfully built ...`)
6. `docker push casecommons/<INSERT REPO NAME>:$(git rev-parse --short HEAD)` to docker hub
7. `cd ..` and repeat the above steps for `casebook_api`

## Creating an Ansible Control Host.

If you are setting up the infrastructure for the first time, you will need to provision a server to act as the Ansible control host.   Start from a VM with RHEL 7 or higher.


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
  - Create an S3 bucket for storing secrets (eg, call it `accelerator-s3-secrets`)
  - Upload all the secret files to S3. You will need the following:
    1. `nginx.crt`
    2. `nginx.key`
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
   Run command `ssh-keygen`, taking all the defaults by hitting <enter> until you get back your command prompt.

6. Copy your Ansible hosts public key (*.pub) to all client machines that will be managed by Ansible into file `/$USER/.ssh/authorized_keys`

7. git clone this repo. `git clone https://github.com/Casecommons/accelerator-ansible.git`

8. `cd accelerator-ansible`

9. Create an inventory file: `cp ./hosts.sample ./hosts`

10. In the `hosts` file, under `[logging-node]` and `[api-node]` and `[intake-node]`, insert the clients that will be managed by Ansible (one ip address or hostname per line). 

11. Create a vars file:`cp ./group_vars/all.sample ./group_vars/all`

12. Now update the `./group_vars/all` file (Note: `intake_elasticsearch_url` and `elasticsearch_log_server` should point to the private IP on AWS. `intake_elasticsearch_url` specifically, is a tempoary solution until we figure out how search will be implemented with the partner): 
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
   - intake_image_tag from [here](https://hub.docker.com/r/casecommons/ca_intake/tags/)
   - api_image_tag from [here](https://hub.docker.com/r/casecommons/casebook_api/tags/)

13. Verify that the Ansible host can talk to the client:
  ```
   ansible intake-node -m ping
   ansible api-node -m ping
   ansible logging-node -m ping
  ```
  You should see a success message.
14. Follow the deploy section below


## Deploying

1. SSH into the Ansible Control Host and follow the remaining instructions.
2. `cd  /home/ec2-user/accelerator-ansible`
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

4. To verify connectivity between the Ansible control server and the clients: `ansible -i ./hosts all -m ping`
  (Note: All clients should succeed except for the ansible host)

5. Change directories: `cd  groups_vars`

6. Copy this file: `cp  all.sample  all`

7. Edit this file: `vi  all`  

    ```
    elasticsearch_log_server: <INSERT_IP_OR_SERVER_NAME>
    intake_image_tag: <INSERT_IMAGE_TAG_HERE>
    api_image_tag: <INSERT_IMAGE_TAG_HERE>
    ``` 

8. Now run the following Ansible playbooks:
   ```
    `ansible-playbook -i ./hosts config-logging-node.yml`
    `ansible-playbook -i ./hosts config-docker-api-node.yml` (Note: You'll be prompted for your dockerhub credentials)
    `ansible-playbook -i ./hosts config-docker-intake-node.yml` (Note: You'll be prompted for your dockerhub credentials) 
   ```

 (NOTE: The playbook will prompt you for your dockerhub login, password, and email.)

9. If you are on AWS:

- Open your security group to accept incoming traffic from port 80.
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

## Logging

Logging is done with Rsyslog, Kibana, and Elastic search. Rsyslog is pre-installed on each docker host.  Any docker containers will log to the local rsyslog socket. The docker-compose file `docker-compose.log.yml` includes the logging stack as part of this single-node playbook. Feel free to break this up into seperate services when doing multi-node deploys, e.g, kibana on a separate instance.

Alternatively, you can have a Rsyslog container. Just remember to mount the `/dev/log` socket to the host: ` docker run ... -v /dev/log:/dev/log ...`

## License

The Accelerator Playbooks software is free: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

The Accelerator Playbooks software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more details.

See https://www.gnu.org/licenses/agpl.html

## Copyright

Copyright (c) 2016 Case Commons, Inc.
