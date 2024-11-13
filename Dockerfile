FROM ubuntu:22.04 AS docker

RUN apt update && \
    apt-get install -y ca-certificates curl && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" | tee /etc/apt/sources.list.d/docker.list && \
    apt update && \
    apt-get install -y docker-ce-cli

FROM ubuntu:22.04 AS agentpolicy

RUN apt update && \
    apt install -y xz-utils curl

WORKDIR /kata

# Download the 3.9.0 version of agent policy
RUN ARCH="$(dpkg --print-architecture)" && \
    curl -LO "https://github.com/kata-containers/kata-containers/releases/download/3.9.0/kata-static-3.9.0-${ARCH}.tar.xz" && \
    tar -xJf kata-static-3.9.0-${ARCH}.tar.xz

FROM ubuntu:22.04

COPY --from=docker /usr/bin/docker /usr/bin/docker

COPY --from=agentpolicy /kata/opt/kata/bin /opt/kata/bin

RUN ARCH="$(dpkg --print-architecture)" && \
    apt update && \
    apt install -y \
    curl \
    vim \
    openssh-client \
    git \
    jq \
    git \
    make \
    skopeo \
    tmux \
    gettext-base \
    bat \
    python3 && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && chmod +x ./kubectl && mv ./kubectl /usr/bin && \
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && mv ./kustomize /usr/bin && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    ln -s /usr/bin/batcat /usr/local/sbin/cat && \
    echo "export PATH="\$PATH:/opt/kata/bin >> /etc/profile.d/50-kata.sh && \
    chmod +x /etc/profile.d/50-kata.sh

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
