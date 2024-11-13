DOCKER_IMAGE = "ghcr.io/surajssd/kubecon-na24-workshop-base"
DOCKER_IMAGE_DEMO2 = "ghcr.io/surajssd/kubecon-na24-workshop-demo2"

.PHONY: docker-build
docker-build:
	docker build -t $(DOCKER_IMAGE) .

.PHONY: docker-run
docker-run:
	-docker run -d --name kubecon-na24-workshop-base \
		-v $(shell pwd):/kubecon-na24-workshop-base \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e USER_ID=$(shell id -u) \
		-e GROUP_ID=$(shell id -g) \
		-e USER_NAME=$(shell id -un) \
                --platform linux/amd64 \
		--workdir /kubecon-na24-workshop-base \
		--rm \
		$(DOCKER_IMAGE)
	sleep 5
	docker exec -it kubecon-na24-workshop-base su $(shell id -un)

.PHONY: clean
clean:
	rm -rf artifacts

.PHONY: docker-build-demo2
docker-build-demo2:
	docker build -t $(DOCKER_IMAGE_DEMO2) -f demos/demo2/app/Dockerfile demos/demo2/app
