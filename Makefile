DOCKER_IMAGE = "ghcr.io/surajssd/kubecon-na24-workshop"

.PHONY: docker-build
docker-build:
	docker build -t $(DOCKER_IMAGE) .

.PHONY: docker-run
docker-run:
	-docker run -d --name kubecon-na24-workshop \
		-v $(shell pwd):/kubecon-na24-workshop \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e USER_ID=$(shell id -u) \
		-e GROUP_ID=$(shell id -g) \
		-e USER_NAME=$(shell id -un) \
		--workdir /kubecon-na24-workshop \
		$(DOCKER_IMAGE)
	sleep 5
	docker exec -it kubecon-na24-workshop su $(shell id -un)

.PHONY: clean
clean:
	rm -rf artifacts
