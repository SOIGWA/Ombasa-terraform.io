<img src="https://cdn.prod.website-files.com/677c400686e724409a5a7409/6790ad949cf622dc8dcd9fe4_nextwork-logo-leather.svg" alt="NextWork" width="300" />

# Threat Detection with GuardDuty

**Project Link:** [View Project](http://learn.nextwork.org/projects/aws-security-guardduty)

**Author:** Andy Ombasa  
**Email:** andyombasa@gmail.com

---

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_v1w2x3y4)

---

## Introducing Today's Project!

### Tools and concepts

The services I used were Amazon S3, Amazon EC2, AWS CloudShell, Amazon CloudFormation, and Amazon GuardDuty. Key concepts I learnt include the Principle of Least Privilege, the mechanics of IAM role credential exfiltration, how AWS GuardDuty anomaly detection identifies suspicious API calls from unauthorized sources, and the importance of monitoring and logging for timely threat response.

### Project reflection

This project took me approximately 2 hours to complete. The most challenging part was troubleshooting the 403 Forbidden errors and correctly configuring the stolen profile variables to successfully simulate the exfiltration. It was most rewarding to see the GuardDuty dashboard light up with a high-severity finding almost immediately after the attack, which perfectly demonstrated the efficacy of real-time threat detection in an AWS environment.

I undertook this project to deepen my practical understanding of cloud security, specifically how to detect and respond to credential exfiltration,a critical skill for a Cloud Engineering and DevOps professional. By simulating a real-world attack and observing how Amazon GuardDuty flags unauthorized access, I've gained invaluable hands-on experience in building more resilient, secure architectures.

---

## Project Setup

To set up for this project, I deployed a CloudFormation template that launches an AWS environment. The three main components are:

Web App Infrastructure: Includes EC2 instances, a custom VPC, subnets, internet gateway, route tables, VPC endpoints, an Elastic Load Balancer, Auto Scaling, and CloudFront to host and scale the application.

S3 Bucket: Stores sensitive data (important-information.txt) accessible by the EC2 instance, serving as the target for a simulated data breach.

GuardDuty: Automatically enabled to provide threat detection and monitor the infrastructure for security vulnerabilities.

The web app deployed is called OWASP Juice Shop, which is a deliberately vulnerable application designed for security testing. To practice my GuardDuty skills, I will act as both the attacker and the defender by executing a simulated data breach,including exploiting web vulnerabilities to steal instance credentials and accessing the sensitive data stored in the S3 bucket so that I can observe how GuardDuty identifies and alerts on these malicious activities in real-time.

GuardDuty is a continuous security monitoring and threat detection service in AWS. In this project, it will actively analyze your environment for security vulnerabilities and potential threats. By monitoring the interactions between your web server and the S3 bucket, it aims to detect the malicious activity and unauthorized access patterns that will occur during the simulated data breach.

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_n1o2p3q4)

---

## SQL Injection

The first attack I performed on the web app is SQL injection, which means injecting malicious SQL code into input fields to manipulate the backend database queries. SQL injection is a security risk because it allows an attacker to bypass authentication, view unauthorized data, modify or delete database records, and in some cases, gain full administrative control over the application's underlying data.

My SQL injection attack involved entering ' or 1=1;-- into the login field. This means I manipulated the backend database query by injecting a logical condition that always evaluates to true, effectively bypassing the password check and tricking the application into granting me access to the admin account as if I were a legitimate user.

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_h1i2j3k4)

---

## Command Injection

Next, I used command injection, which is a technique where an attacker executes arbitrary operating system commands on the server running an application by injecting them into vulnerable input fields. The Juice Shop web app is vulnerable to this because it improperly sanitizes user input, allowing an attacker to escape the application's intended context and run shell commands with the privileges of the web server, effectively granting control over the underlying host.

To perform command injection, I inserted a Node.js exec command into a vulnerable input field. The script fetches the EC2 IAM role credentials via the Metadata Service  and saves them as a JSON file in the web app's public assets folder, making the stolen credentials easily accessible for further unauthorized use.

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_t3u4v5w6)

---

## Attack Verification

o verify the attack's success, I navigated to the specific URL where the script saved the results, /assets/public/credentials.json. The credentials page showed me the live, temporary AWS IAM credentials including the AccessKeyId, SecretAccessKey, and Token that were successfully exfiltrated from the EC2 instance's metadata service, confirming that I now have the ability to authenticate as the instance's IAM role.

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_x7y8z9a0)

---

## Using CloudShell for Advanced Attacks

The attack continues in CloudShell, because it provides an environment directly within my AWS account to simulate how an attacker uses stolen credentials to interact with AWS services. By executing CLI commands here to access the S3 bucket, I can replicate the unauthorized API calls a threat actor would make, allowing me to observe the full attack chain and verify if my security monitoring tools are functioning as intended.

In CloudShell, I used wget to download the credentials.json file I had previously exfiltrated and stored in the web app's public assets folder. Next, I ran a command using cat and jq to display the contents of that JSON file in a formatted, readable way, allowing me to easily extract and copy the AccessKeyId, SecretAccessKey, and Token needed to authenticate with the AWS CLI and finalize the data breach.

I set up a profile called stolen to authenticate the AWS CLI using the exfiltrated IAM credentials. I had to create a new profile to separate my attacker session from my regular administrative access; this allows me to perform unauthorized API actions as a malicious actor, creating a distinct trail of activity for me to analyze in GuardDuty and verify if my security monitoring is effective.

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_j9k0l1m2)

---

## GuardDuty's Findings

After performing the attack, GuardDuty reported a finding within a few minutes, illustrating the platform's capability for near real-time threat detection. Findings are prioritized alerts generated by analyzing VPC Flow Logs, CloudTrail events, and DNS logs to identify suspicious activity, such as unauthorized access from unusual locations or attempts to exfiltrate data from protected S3 buckets.

GuardDuty’s finding was titled "Credentials for the EC2 instance role were used from a remote AWS account." This means GuardDuty detected the IAM role’s credentials being accessed outside their intended environment. Anomaly detection was used because GuardDuty established a normal baseline for your identity and flagged these API calls as a deviation, identifying them as a high-severity threat.

GuardDuty's detailed finding reported that unauthorized API calls, specifically ListObjects, were made to the S3 bucket nextwork-guardduty-project-andyomb-thesecurebucket-ftwthwgjlprp using credentials associated with the EC2 instance role NextWork-GuardDuty-project-AndyOmbasa. The alert identified that these calls originated from a remote IP address  in Ashburn, United States, which deviated from the expected behavior for that role. The finding also captured that these unauthorized attempts resulted in AccessDenied errors, confirming that the security controls successfully blocked part of the malicious activity while triggering a high-severity alert for the suspicious credential usage.

![Image](http://learn.nextwork.org/relaxed_gold_beautiful_beaver/uploads/aws-security-guardduty_v1w2x3y4)

---

## Extra: Malware Protection

---
