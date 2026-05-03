#!/bin/bash

# Switch to root user
sudo -i

# Update the system
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release unzip

export CPU_TYPE=$(uname -m)
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-${CPU_TYPE}.zip" -o "awscliv2.zip"
sudo unzip awscliv2.zip
sudo ./aws/install

# Install SSM Agent using snap (recommended for Ubuntu 16.04 and later)
sudo snap install amazon-ssm-agent --classic

# Start and enable the SSM Agent service
sudo snap start amazon-ssm-agent
sudo snap enable amazon-ssm-agent

# Verify the agent is running
sudo snap services amazon-ssm-agent