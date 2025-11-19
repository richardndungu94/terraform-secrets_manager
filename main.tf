# main.tf
   
# Creates a random string to be used as a suffix for resource names
resource "random_string" "suffix" {
    length  = 6
     special = false
    upper   = false
     number  = true
    }
   
# Creates an IAM role that can be assumed by EC2 instances
    resource "aws_iam_role" "ec2_with_secrets" {
      name = "secrets-demo-ec2-role-${random_string.suffix.result}"
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
            Service = "ec2.amazonaws.com"
          }
          }
        ]
      })
      tags = {
        Name    = "secrets-demo-ec2-role"
      Project = "secrets-demo"
      }
    }
    
   
   # Creates an instance profile to make the IAM role available to EC2
    resource "aws_iam_instance_profile" "ec2_profile" {
     name = aws_iam_role.ec2_with_secrets.name
     role = aws_iam_role.ec2_with_secrets.name
   }
   
    # Creates a secret in AWS Secrets Manager
    resource "aws_secretsmanager_secret" "ssh_key" {
     name        = "secrets-demo-ssh-key-${random_string.suffix.result}"
     description = "SSH private key - stored securely, never in Git"
     recovery_window_in_days = 7
     tags = {
       Name        = "secrets-demo-ssh-key"
      Project     = "secrets-demo"
       Environment = "dev"
       ManagedBy   = "Terraform"
      }
    }
    
   # Creates a version of the secret with a dummy value
   resource "aws_secretsmanager_secret_version" "ssh_key" {
      secret_id     = aws_secretsmanager_secret.ssh_key.id
     secret_string = "{\"private_key\":\"dummy-key-for-testing\"}"
   }
   
   # Creates an IAM policy that allows reading the secret
   resource "aws_iam_policy" "read_ssh_secret" {
      name        = "secrets-demo-read-ssh-secret-${random_string.suffix.result}"
     description = "Allow reading SSH key from Secrets Manager"
     policy      = data.aws_iam_policy_document.read_secret.json
      tags = {
        Name    = "secrets-demo-read-ssh-secret-policy"
        Project = "secrets-demo"
    }
    }
   
   # Attaches the policy to the role
   resource "aws_iam_role_policy_attachment" "ec2_secrets_access" {
      role       = aws_iam_role.ec2_with_secrets.name
      policy_arn = aws_iam_policy.read_ssh_secret.arn
    }
   
   # Data source to construct the IAM policy document
   data "aws_iam_policy_document" "read_secret" {
     statement {
       sid    = "ReadSSHSecret"
       effect = "Allow"
        actions = [
          "secretsmanager:GetSecretValue",
         "secretsmanager:DescribeSecret"
       ]
       resources = [
          aws_secretsmanager_secret.ssh_key.arn
        ]
      }
    }

