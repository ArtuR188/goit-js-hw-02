Artur Vynokur 4CS-32
# Configure the AWS CLI

Before starting work, you need to download the AWS CLI and install it for your operating system https://docs.aws.amazon.com/cli/latest/
Before running commands in this project, **make sure to configure the AWS CLI**.

## 1. Run the configuration

Run the command:

```bash
aws configure
```
You will need your Amazon AWS Access Key ID and
AWS Secret Access Key and specify the
Default region name

## 2. Preparing an SSH Key
Make sure your private SSH key (UbuntuKey.pem) is located in the project's root folder and matches the name specified in the KEY_PATH variable in deploy.sh.

```bash
KEY_PATH="./UbuntuKey.pem"
```

## 3. Deployment and Launch
## The deploy.sh script performs the following tasks:

Creates an EC2 instance (Task 1).

```bash
chmod +x deploy.sh
./deploy.sh
```

## 4. 