FROM jenkins/jenkins:lts
# if we want to install via apt
USER root
RUN apt-get update && \
    apt-get install -y apt-utils \
    -y curl \
    unzip

# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest#install
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# https://www.terraform.io/downloads.html
RUN curl https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip --output terraform.zip

# unzip terraform
RUN unzip terraform.zip

# move to usr/local/bin directory
RUN mv terraform usr/local/bin

# clean up
RUN rm terraform.zip    

# drop back to the regular jenkins user - good practice
USER jenkins