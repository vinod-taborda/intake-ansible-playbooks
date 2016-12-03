include Makefile.settings

.PHONY: init build jenkins slave clean logs

export JENKINS_USERNAME ?= admin
export JENKINS_PASSWORD ?= password

init:
	${INFO} "Checking network..."
	@ $(if $(NETWORK_ID),,docker network create $(NETWORK_NAME))
	${INFO} "Creating volumes..."
	@ docker volume create --name=jenkins_home

build: init
	${INFO} "Building image..."
	@ docker-compose -f docker-compose.jenkins.yml build --pull
	${INFO} "Build complete"

jenkins: init
	${INFO} "Starting jenkins..."
	@ docker-compose -f docker-compose.jenkins.yml up -d jenkins
	${INFO} "Jenkins has started..."
	${INFO} "Streaming Jenkins logs - press CTRL+C to exit..."
	@ docker-compose -f docker-compose.jenkins.yml logs -f jenkins

slave: init
	${INFO} "Running $(SLAVE_COUNT) slave(s)..."
	@ docker-compose -f docker-compose.jenkins.yml scale jenkins-slave=$(SLAVE_COUNT)
	${INFO} "$(SLAVE_COUNT) slave(s) running"

clean:
	${INFO} "Stopping services..."
	@ docker-compose -f docker-compose.jenkins.yml down -v || true
	${INFO} "Services stopped"

logs:
	@ docker-compose -f docker-compose.jenkins.yml logs -f
