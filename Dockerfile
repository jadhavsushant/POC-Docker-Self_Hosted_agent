FROM ubuntu:18.04

#Install the tools
RUN apt-get update && DEBIAN_FRONTEND="noninteractive" TZ="America/New_York" apt-get install -y
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  cron \
  jq \
  rsync \
  git \
  iputils-ping \
  libcurl4 \
  libunwind8 \
  netcat \
  libssl1.0-dev \
  libffi-dev \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  zip \
  vim \
  unzip \
  wget \
  nano \
  apt-utils \
  less \
  locales \
  gss-ntlmssp \
  openssh-client \
  && rm -rf /var/lib/apt/lists/*

#Install the Python packages
RUN apt-get update \
  && apt-get install -y python3-pip python3-dev \
  && cd /usr/local/bin \
  && ln -s /usr/bin/python3 python \
  && pip3 --no-cache-dir install --upgrade pip \
  && rm -rf /var/lib/apt/lists/*


#install the kubectl,azcli, Azcopy
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

RUN apt-get update && apt-get -y upgrade && \
  curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
  CLI_REPO=$(lsb_release -cs) && \
  echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${CLI_REPO} main" \
  > /etc/apt/sources.list.d/azure-cli.list && \
  apt-get update && \
  apt-get install -y azure-cli && \
  rm -rf /var/lib/apt/lists/*

RUN set -ex \
  && curl -L -o azcopy.tar.gz \
  https://aka.ms/downloadazcopylinux64 \
  && tar -xf azcopy.tar.gz && rm -f azcopy.tar.gz \
  && ./install.sh && rm -f install.sh

# Install Powershell
ARG PS_VERSION=7.1.3
ARG PS_PACKAGE=powershell_${PS_VERSION}-1.ubuntu.18.04_amd64.deb
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${PS_PACKAGE}

# Define ENVs for Localization/Globalization
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
  LC_ALL=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  # set a fixed location for the Module analysis cache
  PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache \
  POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-Ubuntu-18.04

RUN apt-get update \
  && apt-get install --no-install-recommends -y \
  && echo ${PS_PACKAGE_URL} \
  && curl -sSL ${PS_PACKAGE_URL} -o /tmp/powershell.deb \
  && apt-get install --no-install-recommends -y /tmp/powershell.deb \
  && apt-get dist-upgrade -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && locale-gen $LANG && update-locale \
  # remove powershell package
  && rm /tmp/powershell.deb \
  && ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh \
  # intialize  module cache
  # and disablepowershell telemetry
  && export POWERSHELL_TELEMETRY_OPTOUT=1 \
  && pwsh \
  -NoLogo \
  -NoProfile \
  -Command " \
  \$ErrorActionPreference = 'Stop' ; \
  \$ProgressPreference = 'SilentlyContinue' ; \
  while(!(Test-Path -Path \$env:PSModuleAnalysisCachePath)) {  \
  Write-Host "'Waiting for $env:PSModuleAnalysisCachePath'" ; \
  Start-Sleep -Seconds 6 ; \
  }"

# Install Miniconda
RUN curl -sL https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -o miniconda.sh \
    && chmod +x miniconda.sh \
    && ./miniconda.sh -b -p /usr/share/miniconda \
    && rm miniconda.sh
RUN CONDA=/usr/share/miniconda \
    && echo "CONDA=$CONDA" | tee -a /etc/environment \
    && ln -s $CONDA/bin/conda /usr/bin/conda

# adding script file to configure the ADO-Agent

RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
    && rm -rf /var/lib/apt/lists/*
ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.185.1
WORKDIR /azp
RUN if [ "$TARGETARCH" = "amd64" ]; then \
  AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
  else \
  AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
  fi; \
  curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz
COPY ./start.sh .
RUN chmod +x start.sh
ENTRYPOINT [ "./start.sh" ]