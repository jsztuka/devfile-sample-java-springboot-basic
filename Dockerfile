FROM registry.access.redhat.com/ubi9/go-toolset:9.6-1747333074 as check-payload-build

WORKDIR /opt/app-root/src

ARG CHECK_PAYLOAD_VERSION=0.3.6
ARG PATH_TO_ART=/cachi2/output/deps/generic

# Container image that runs your code
FROM docker.io/snyk/snyk:linux@sha256:6d26ce5ef31116eb21315b99f1b0970ca3cc6267174cd6f3de1cb375bd782083 as snyk
FROM quay.io/enterprise-contract/ec-cli:snapshot@sha256:6491f75e335015b8e800ca4508ac0cd155aeaf3a89399bc98949f93860a3b0a5 AS ec-cli
FROM ghcr.io/sigstore/cosign/cosign:v99.99.91@sha256:8caf794491167c331776203c60b7c69d4ff24b4b4791eba348d8def0fd0cc343 as cosign-bin
FROM registry.access.redhat.com/ubi9/ubi:9.6-1747219013

# Note that the version of OPA used by pr-checks must be updated manually to reflect conftest updates
# To find the OPA version associated with conftest run the following with the relevant version of conftest:
# $ conftest --version
ARG conftest_version=0.45.0
ARG BATS_VERSION=1.8.2
ARG sbom_utility_version=0.12.0
ARG OPM_VERSION=v1.40.0
ARG UMOCI_VERSION=v0.4.7

ENV POLICY_PATH="/project"

#ADD https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm epel-release-latest-9.noarch.rpm

# Build dependency offline to streamline build
#rpm -Uvh epel-release-latest-9.noarch.rpm && \
RUN dnf install -y --nogpgcheck jq \
    skopeo \
    tar \
    python3 \
    clamav \
    clamd \
    csdiff \
    git \
    # Remove golang after https://github.com/openshift/check-payload/issues/231 is resolved
    golang \
    python3-file-magic \
    python3-pip \
    ShellCheck \
    csmock-plugin-shellcheck-core \
    libicu

#yq
RUN pip install "${PATH_TO_ART}"/PyYAML-6.0.2-cp39-cp39-manylinux_2_17_x86_64.manylinux2014_x86_64.whl "${PATH_TO_ART}"/argcomplete-3.6.2-py3-none-any.whl "${PATH_TO_ART}"/tomlkit-0.13.3-py3-none-any.whl "${PATH_TO_ART}"/xmltodict-0.14.2-py2.py3-none-any.whl "${PATH_TO_ART}"/yq-3.4.3-py3-none-any.whl

#check-payload
RUN tar -xzf ${PATH_TO_ART}/check-payload.tar.gz && cd check-payload-${CHECK_PAYLOAD_VERSION} && \
    CGO_ENABLED=0 go build -ldflags="-X main.Commit=${CHECK_PAYLOAD_VERSION}" -o /opt/app-root/src/check-payload-binary && \
    chmod +x /opt/app-root/src/check-payload-binary

#sbom-utility
RUN mkdir sbom-utility && tar -xf ${PATH_TO_ART}/sbom-utility.tar.gz -C sbom-utility

#oc/ppc64le/arch64
RUN tar -xzvf ${PATH_TO_ART}/openshift-client-linux-amd64.tar.gz -C /usr/bin
RUN tar -xzvf ${PATH_TO_ART}/openshift-client-linux-ppc64le.tar.gz -C /usr/bin

#bats-core
RUN tar -xf ${PATH_TO_ART}/v1.8.2.tar.gz && \
    cd "bats-core-$BATS_VERSION" && \
    ./install.sh /usr && \
    cd .. && rm -rf "bats-core-$BATS_VERSION" && \
    cd /

#opm
RUN  cp ${PATH_TO_ART}/linux-amd64-opm /usr/bin/opm && chmod +x /usr/bin/opm

#umoci
RUN  cp ${PATH_TO_ART}/umoci.amd64 /usr/bin/umoci && chmod +x /usr/bin/umoci

#opa
RUN cp ${PATH_TO_ART}/opa_linux_amd64_static /usr/bin/opa && chmod +x /usr/bin/opa




ENV PATH="${PATH}:/sbom-utility"

COPY --from=snyk /usr/local/bin/snyk /usr/local/bin/snyk

COPY --from=ec-cli /usr/local/bin/ec /usr/local/bin/ec

COPY --from=cosign-bin /ko-app/cosign /usr/local/bin/cosign

COPY --from=check-payload-build /opt/app-root/src/check-payload-binary /usr/bin/check-payload


RUN ls /
RUN ls /cachi2/
RUN ls /cachi2/output
RUN ls /cachi2/output/deps
RUN ls /cachi2/output/deps/generic
#RUN cp /cachi2/output/deps/dependency-check.zip /var
