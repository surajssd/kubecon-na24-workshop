FROM ubuntu:22.04

RUN apt update && \
    apt install -y \
    curl \
    vim \
    openssh-client \
    git \
    jq \
    git \
    python3 && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x ./kubectl && mv ./kubectl /usr/bin && \
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && mv ./kustomize /usr/bin && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash
