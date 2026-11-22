FROM jenkins/jenkins:lts-jdk21

USER root

ARG TERRAFORM_VERSION=1.17.2
ARG TERRAGRUNT_VERSION=1.2.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    tmp="$(mktemp -d)"; \
    cd "$tmp"; \
    tf_archive="terraform_${TERRAFORM_VERSION}_linux_${arch}.zip"; \
    tf_url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"; \
    curl -fsSLO "$tf_url/$tf_archive"; \
    curl -fsSLO "$tf_url/terraform_${TERRAFORM_VERSION}_SHA256SUMS"; \
    awk -v file="$tf_archive" '$2 == file' "terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c -; \
    unzip "$tf_archive" terraform -d /usr/local/bin; \
    tg_binary="terragrunt_linux_${arch}"; \
    tg_url="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}"; \
    curl -fsSLO "$tg_url/$tg_binary"; \
    curl -fsSLO "$tg_url/SHA256SUMS"; \
    awk -v file="$tg_binary" '$2 == file' SHA256SUMS | sha256sum -c -; \
    install -m 0755 "$tg_binary" /usr/local/bin/terragrunt; \
    rm -rf "$tmp"

USER jenkins
