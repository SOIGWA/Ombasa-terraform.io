Putting It All Together: Application and Infrastructure Workflows with Terraform
Introduction
Building infrastructure in a silo is one thing; integrating it into a living, breathing CI/CD pipeline is where the "Dev" truly meets the "Ops." Over the past few weeks, I’ve been refining a workflow that treats infrastructure as code not just in name, but in practice. Today, I’m breaking down the integrated pipeline that powers my webserver-cluster and the guardrails that keep it stable and cost-effective.

1. The Integrated Pipeline
The heart of this setup is a GitHub Actions workflow that triggers on every pull request. This ensures that no code reaches production without being vetted by a series of automated gates.

The Workflow Stages:
Static Analysis: Every run begins with terraform fmt and terraform validate to catch syntax errors and style inconsistencies.

Automated Testing: Using the new terraform test framework, the pipeline runs unit tests against the module to ensure variables (like cluster_name) and resource configurations meet expectations.

Plan Generation: Once validated, the pipeline runs a terraform plan. This plan is saved as a binary artifact, ensuring that what we see in the PR is exactly what gets deployed later.

2. The Immutable Artifact Promotion Pattern
In this workflow, I follow the Immutable Artifact pattern. Instead of running a fresh terraform plan during the deployment phase, the pipeline "promotes" the plan file generated during the CI stage.

Why it matters: This prevents "environment drift" where the cloud state might change between the time a plan is approved and the time it is applied.

How it works: The ci.tfplan is uploaded as a GitHub artifact. If the PR is merged, the deployment job downloads that specific file and runs terraform apply ci.tfplan.

3. Policy as Code: Sentinel & Cost Estimation
To move beyond basic validation, I’ve integrated Policy as Code using HashiCorp Sentinel and cost-estimation gates.

The Guardrails:
Sentinel Policies: These are logical "rules" that check our plan. For example, a policy might mandate that all EC2 instances must be t2.micro or t3.micro to prevent accidental high-cost resource provisioning.

Cost Estimation Gate: Before the "Apply" button is even an option, Terraform Cloud calculates the monthly cost delta. If a change increases our AWS bill by more than a specific threshold (e.g., $100/month), the pipeline requires an extra manual approval from a lead engineer.

4. Reflection: What Clicked, What Broke, and What Surprised Me
What Clicked
The moment I finally understood the -chdir logic and how GitHub Actions interacts with the root directory vs. module directories, everything fell into place. Seeing the first green checkmark after a series of "No such file or directory" errors was incredibly satisfying.

What Broke (and how I fixed it)
The "Interactive Prompt" was my biggest hurdle this week. I had a variable for environment that didn't have a default value. In my local terminal, I’d just type "dev," but in the CI pipeline, it just hung there forever. Fixing that by passing -var="environment=dev" in the YAML was a "lightbulb" moment for how automation requires explicit instructions.

What Surprised Me
I was surprised by how protective the AWS Provider is regarding credentials. The no EC2 IMDS role found error taught me a lot about how the AWS SDK searches for identity. It doesn't just look for environment variables; it actively probes the system it's running on. Learning to use the aws-actions/configure-aws-credentials action was a game-changer for stability.

Conclusion
Infrastructure automation isn't about writing code once; it's about building a system that can reliably test and deploy that code. This journey from a local main.tf to a fully automated, policy-guarded GitHub pipeline has transformed how I view cloud engineering.
