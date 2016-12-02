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
	@ docker-compose build --pull
	${INFO} "Build complete"

jenkins: init
	${INFO} "Starting jenkins..."
	@ docker-compose up -d jenkins
	${INFO} "Jenkins has started..."
	${INFO} "Streaming Jenkins logs - press CTRL+C to exit..."
	@ docker-compose logs -f jenkins

slave: init
	${INFO} "Running $(SLAVE_COUNT) slave(s)..."
	@ docker-compose scale jenkins-slave=$(SLAVE_COUNT)
	${INFO} "$(SLAVE_COUNT) slave(s) running"

clean:
	${INFO} "Stopping services..."
	@ docker-compose down -v || true
	${INFO} "Services stopped"

logs:
	@ docker-compose logs -f
