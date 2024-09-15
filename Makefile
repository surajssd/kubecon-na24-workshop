DOCKER_IMAGE = "quay.io/surajd/kubecon-na-2024-workshop"

.PHONY: docker-build
docker-build:
	docker build -t $(DOCKER_IMAGE) .

.PHONY: docker-push
docker-push:
	docker push $(DOCKER_IMAGE)

.PHONY: docker-run
docker-run:
	docker run -it \
		-v $(shell pwd):/kubecon-na24-workshop \
		--workdir /kubecon-na24-workshop \
		$(DOCKER_IMAGE) bash

.PHONY: clean
clean:
	rm -rf artifacts
