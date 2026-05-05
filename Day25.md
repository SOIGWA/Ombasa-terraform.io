🛠️ Technical Deep Dive
1. S3 and CloudFront Configuration
The website is hosted in an S3 Bucket configured for static website hosting. However, S3 alone isn't enough for a modern site. I integrated Amazon CloudFront as a Content Delivery Network (CDN) to:

⚡ Improve Speed: Cache content at edge locations closer to users.

🔒 Security: Enforce HTTPS via the viewer_protocol_policy = "redirect-to-https" setting.

2. 🛡️ Remote State & Locking
I configured a Remote Backend using an S3 bucket and a DynamoDB table.

S3: Stores the terraform.tfstate file so that if my laptop crashes, the infrastructure record isn't lost.

DynamoDB: Enables State Locking. This prevents two people from running Terraform at the same time, which could corrupt the infrastructure.

🚀 The Deployment Process
Initialize: terraform init to download providers and set up the remote backend.

Plan: terraform plan to preview the changes.

Apply: terraform apply to provision the resources on AWS.

🌐 Live Website URL
After the deployment finished, Terraform provided the CloudFront domain name as an output. You can view the live site here:

URL: http://d3d3arkppp664v.cloudfront.net

📝 Lessons Learned
The most important takeaway from this project was handling S3 naming conventions. I learned that S3 buckets must be globally unique and strictly lowercase. Even a single capital letter will cause the AWS API to reject the creation.

By using Terraform, I’ve turned a manual process into a "one-click" deployment that is documented, version-controlled, and ready for the cloud. ☁️
