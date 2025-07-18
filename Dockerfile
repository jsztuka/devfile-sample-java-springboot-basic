FROM registry.access.redhat.com/ubi9/go-toolset:1.23.6-1745328278 as check-payload-build

WORKDIR /opt/app-root/src

ARG CHECK_PAYLOAD_VERSION=0.3.5

RUN curl -s -L -o check-payload.tar.gz "https://github.com/openshift/check-payload/archive/refs/tags/${CHECK_PAYLOAD_VERSION}.tar.gz" && \
    tar -xzf check-payload.tar.gz && rm check-payload.tar.gz && cd check-payload-${CHECK_PAYLOAD_VERSION} && \
    CGO_ENABLED=0 go build -ldflags="-X main.Commit=${CHECK_PAYLOAD_VERSION}" -o /opt/app-root/src/check-payload-binary && \
    chmod +x /opt/app-root/src/check-payload-binary

# Container image that runs your code
FROM docker.io/snyk/snyk:linux@sha256:2c95c561dbafb52573ccc862b485ac0d1a20e720c557db2684409768809cdc17 as snyk
FROM quay.io/enterprise-contract/ec-cli:snapshot@sha256:6491f75e335015b8e800ca4508ac0cd155aeaf3a89399bc98949f93860a3b0a5 AS ec-cli
FROM ghcr.io/sigstore/cosign/cosign:v99.99.91@sha256:8caf794491167c331776203c60b7c69d4ff24b4b4791eba348d8def0fd0cc343 as cosign-bin
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.5-1745845495

# Note that the version of OPA used by pr-checks must be updated manually to reflect conftest updates
# To find the OPA version associated with conftest run the following with the relevant version of conftest:
# $ conftest --version
ARG conftest_version=0.45.0
ARG BATS_VERSION=1.6.0
ARG sbom_utility_version=0.12.0
ARG OPM_VERSION=v1.40.0
ARG UMOCI_VERSION=v0.4.7

ENV POLICY_PATH="/project"

ADD https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm epel-release-latest-9.noarch.rpm

# Build dependency offline to streamline build
RUN rpm -Uvh epel-release-latest-9.noarch.rpm && \
    microdnf -y --setopt=tsflags=nodocs --setopt=install_weak_deps=0 install \
    findutils \
    jq
