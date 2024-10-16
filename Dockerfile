FROM ubuntu:22.04 AS docker

RUN apt update && \
    apt-get install -y ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list && \
    apt update && \
    apt-get install -y docker-ce-cli

FROM ubuntu:22.04

COPY --from=docker /usr/bin/docker /usr/bin/docker

RUN apt update && \
    apt install -y \
    curl \
    vim \
    openssh-client \
    git \
    jq \
    git \
    make \
    python3 && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x ./kubectl && mv ./kubectl /usr/bin && \
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && mv ./kustomize /usr/bin && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
