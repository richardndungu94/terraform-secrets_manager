output "secret_arn" {
  description = "ARN of the SSH key secret"
  value       = aws_secretsmanager_secret.ssh_key.arn
}

output "secret_name" {
  description = "Name of the SSH key secret"
  value       = aws_secretsmanager_secret.ssh_key.name
}

output "iam_policy_arn" {
  description = "IAM policy ARN for reading the secret"
  value       = aws_iam_policy.read_ssh_secret.arn
}

output "iam_role_arn" {
  description = "IAM role ARN (can be attached to EC2)"
  value       = aws_iam_role.ec2_with_secrets.arn
}

output "next_steps" {
  description = "What to do next"
  value       = <<-EOT
    Secrets Manager secret created!
    
    Next steps:
    1. Generate SSH key: ./scripts/generate-and-upload-key.sh
    2. View secret: aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.ssh_key.name}
    3. Use in EC2: Attach IAM role ${aws_iam_role.ec2_with_secrets.name} to instances
    
    Test retrieving the secret:
    aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.ssh_key.name} \
      --query 'SecretString' \
      --output text | jq -r '.private_key'
  EOT
}
