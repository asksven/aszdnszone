FROM python:3.8.3 
#mcr.microsoft.com/azure-cli:2.8.0
RUN apt-get update && apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg apt-utils dnsutils
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
ARG AZ_REPO="buster"
RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-get update && apt-get -y install azure-cli

#COPY installAzureCli.sh /

#RUN /installAzureCli.sh
COPY update-ip.sh /
