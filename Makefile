DOCKER_IMAGE = "ghcr.io/surajssd/kubecon-na24-workshop"

.PHONY: docker-build
docker-build:
	docker build -t $(DOCKER_IMAGE) .

.PHONY: docker-run
docker-run:
	docker run -it \
		-v $(shell pwd):/kubecon-na24-workshop \
		-v /var/run/docker.sock:/var/run/docker.sock \
		--workdir /kubecon-na24-workshop \
		$(DOCKER_IMAGE) bash

.PHONY: clean
clean:
	rm -rf artifacts
