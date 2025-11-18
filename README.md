# AWS Secrets Manager for SSH Keys

**Problem:** Developers hardcode SSH keys in code → keys leak in Git → security breach  
**Solution:** Store keys in AWS Secrets Manager → encrypted, audited, never in code

---

## this repo covers

✅ How AWS Secrets Manager works  
✅ How to store SSH keys securely  
✅ How IAM policies control access to secrets  
✅ How EC2 instances retrieve secrets automatically  
✅ Why you should NEVER commit secrets to Git  

---

## What Gets Built

```
AWS Secrets Manager
    ↓
SSH Private Key (encrypted)
    ↓
IAM Policy (who can read it)
    ↓
IAM Role (for EC2 to use)
```



## Quick Start

### 1. Setup

```bash
cd ~/Desktop
mkdir terraform-secrets-manager
cd terraform-secrets-manager

# Create directory
mkdir scripts

# Copy files from artifacts:
# - main.tf
# - variables.tf  
# - outputs.tf
# - scripts/generate-and-upload-key.sh
```

### 2. Deploy

```bash
# Initialize
terraform init

# Deploy
terraform apply
# Type: yes
```

### 3. Generate and Upload SSH Key

```bash
# Make script executable
chmod +x scripts/generate-and-upload-key.sh

# Run it
./scripts/generate-and-upload-key.sh
```

### 4. Test It

```bash
# View the secret
aws secretsmanager get-secret-value \
    --secret-id $(terraform output -raw secret_name) \
    --query 'SecretString' \
    --output text | jq

# Get just the private key
aws secretsmanager get-secret-value \
    --secret-id $(terraform output -raw secret_name) \
    --query 'SecretString' \
    --output text | jq -r '.private_key'
```

---

## How It Works

### The Insecure Way 

```bash
# Hardcoded in code
resource "aws_instance" "web" {
  key_name = "my-key"  # Key stored in AWS, but referenced everywhere
}

# Or worse - in user data:
user_data = <<-EOF
  #!/bin/bash
 
```

**Problems:**
- Keys visible in code
- Keys in Git history forever
- Can't rotate keys easily
- No audit trail of who accessed keys

###  The Secure Way (THIS PROJECT)

```bash
# In Terraform: Just create the secret placeholder
resource "aws_secretsmanager_secret" "ssh_key" {
  name = "my-ssh-key"
}

# In EC2 user-data: Retrieve securely
aws secretsmanager get-secret-value \
  --secret-id my-ssh-key \
  --query 'SecretString' \
  --output text | jq -r '.private_key' > ~/.ssh/id_rsa
```

**Benefits:**
- ✅ Keys never in code
- ✅ Encrypted at rest
- ✅ CloudTrail logs all access
- ✅ Can rotate keys anytime
- ✅ IAM controls who can read

---

## Security Features

### 1. **Encryption**
- Keys encrypted with AWS KMS
- Encrypted at rest in AWS
- Encrypted in transit (TLS)

### 2. **Access Control**
- IAM policies define who can read
- Can restrict by IP, time, MFA
- Follows least-privilege principle

### 3. **Audit Trail**
- CloudTrail logs all secret access
- Know exactly who read what, when
- Compliance-ready logging

### 4. **Rotation**
- Can rotate secrets automatically
- No downtime during rotation
- Old versions kept for rollback

---

## Real-World Usage

### Use Case 1: EC2 Instance Retrieves Key

```hcl
# main.tf
resource "aws_instance" "app" {
  ami           = "ami-xxxxx"
  instance_type = "t3.micro"
  
  # Attach IAM role that can read secrets
  iam_instance_profile = aws_iam_instance_profile.with_secrets.name
  
  user_data = <<-EOF
    #!/bin/bash
    # Retrieve SSH key from Secrets Manager
    aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.ssh_key.name} \
      --query 'SecretString' \
      --output text | jq -r '.private_key' > /home/ec2-user/.ssh/id_rsa
    
    chmod 600 /home/ec2-user/.ssh/id_rsa
    chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
  EOF
}
```

### Use Case 2: Lambda Retrieves Database Password

```python
import boto3
import json

def lambda_handler(event, context):
    # Get secret
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId='db-password')
    secret = json.loads(response['SecretString'])
    
    # Use it
    db_password = secret['password']
    # Connect to database...
```

---

## Testing

### Test 1: Retrieve Secret

```bash
# Get the entire secret
aws secretsmanager get-secret-value \
    --secret-id $(terraform output -raw secret_name)

# Get just private key
aws secretsmanager get-secret-value \
    --secret-id $(terraform output -raw secret_name) \
    --query 'SecretString' \
    --output text | jq -r '.private_key'
```

### Test 2: Check IAM Policy

```bash
# View the policy
aws iam get-policy \
    --policy-arn $(terraform output -raw iam_policy_arn)

# View policy version
aws iam get-policy-version \
    --policy-arn $(terraform output -raw iam_policy_arn) \
    --version-id v1
```

### Test 3: Audit Trail

```bash
# See who accessed the secret
aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=ResourceName,AttributeValue=$(terraform output -raw secret_name) \
    --max-results 5
```

---



---

## Common Mistakes

###  Mistake 1: Storing Secret Value in Terraform

```hcl
# DON'T DO THIS!
resource "aws_secretsmanager_secret_version" "bad" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = "my-actual-secret-key-here"  # Now in Git!
}
```

###  Correct: Use Placeholder + Script

```hcl
# DO THIS!
resource "aws_secretsmanager_secret_version" "good" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = "PLACEHOLDER"
  
  lifecycle {
    ignore_changes = [secret_string]  # Updated by script
  }
}
```

###  Mistake 2: Overly Broad IAM Policy

```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:*",
  "Resource": "*"
}
```

### Correct: Least Privilege

```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": "arn:aws:secretsmanager:region:account:secret:specific-secret"
}
```

---

## Cleanup

```bash
# Destroy everything
terraform destroy
# Type: yes

# Optional: Delete local key
rm ~/.ssh/secrets-demo-key*
```

---

## Next Steps

After mastering this:

1. **Project 2:** CloudTrail - See who accessed your secrets
2. **Project 3:** VPC Flow Logs - Network security monitoring
3. **Project 4:** GuardDuty - Threat detection
4. **Project 5:** CloudWatch Alarms - Get notified of suspicious access

---



## Resources

- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [Terraform AWS Provider - Secrets Manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)

