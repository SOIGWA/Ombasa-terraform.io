Step-by-Step Guide to Setting Up Terraform, AWS CLI, and Your AWS Environment
A clean, up-to-date environment is the foundation of any DevOps project. In this guide, I’ll walk you through exactly how I set up my machine for the 30-Day Terraform Challenge, the specific versions I used, and how to verify everything is working.

1. Installing the AWS CLI (Version 2)
The AWS CLI is our bridge between the local terminal and the cloud. I chose Version 2 as it is the current standard.

The Process:

Download: I used the official MSI installer for Windows.

Install: Ran the .msi and followed the standard prompts.

Verification: Open a new PowerShell window and run:

PowerShell
aws --version
My Output: aws-cli/2.34.10 Python/3.13.11 Windows/11

2. Installing Terraform (v1.14.7)
Unlike many programs, Terraform is a single binary file. There is no "installer" in the traditional sense.

The Process:

Download: I went to the HashiCorp site and downloaded the Windows AMD64 zip file.

Directory Setup: I created a dedicated folder at C:\terraform.

Extract: I moved the terraform.exe from the zip file into that new folder.

Environment Variables: This is the most important step.

Search for "Edit the system environment variables" in Windows.

Click Environment Variables > System Variables > Path > Edit.

Click New and add C:\terraform.

Verification:

PowerShell
terraform version
My Output: Terraform v1.14.7 on windows_amd64

3. Configuring AWS Credentials
To let Terraform talk to my AWS account, I had to configure my IAM credentials.

The Decision: Region Selection
I chose us-east-1 (N. Virginia). It is the most robust region and usually the first to receive new AWS features, making it the safest bet for learning and lab work.

The Command:

PowerShell
aws configure
Access Key ID: [Entered my IAM Access Key]

Secret Access Key: [Entered my IAM Secret Key]

Default region name: us-east-1

Default output format: json

Identity Check:
To ensure I was actually logged into the right account, I ran:

PowerShell
aws sts get-caller-identity
This returned my Account ID and ARN, confirming the connection was live.

4. Running the First "Sanity Check"
In my project folder, I created a main.tf file with a simple AWS provider block and a t2.micro instance. I then ran the three "Golden Commands":

Initialize:

PowerShell
terraform init
This downloads the AWS provider plugin.

Validate:

PowerShell
terraform validate
Success! The configuration is valid.

Plan:

PowerShell
terraform plan
This showed me exactly what Terraform would build without actually spending a cent.

Issues I Hit (and how to fix them)
"Command not found": After adding Terraform to the System Path, I had to restart VS Code and my terminal. The path doesn't update in active windows.

Region Errors: I initially forgot to set the default region in aws configure. Terraform will throw an error during plan if it doesn't know where to build!
