#!/bin/bash
# Generate SSH key pair and upload to AWS Secrets Manager

set -e

echo "========================================"
echo "SSH Key Generation & Upload Script"
echo "========================================"
echo ""

# Check for required tools
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Install: https://aws.amazon.com/cli/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq not found. Install: apt-get install jq or brew install jq"
    exit 1
fi

if ! command -v ssh-keygen &> /dev/null; then
    echo "❌ ssh-keygen not found."
    exit 1
fi

# Check AWS authentication
echo "Checking AWS authentication..."
aws sts get-caller-identity &> /dev/null || {
    echo "❌ Not authenticated with AWS. Run: aws configure"
    exit 1
}
echo "✅ AWS authentication OK"
echo ""

# Get secret name from Terraform output
if [ -f terraform.tfstate ]; then
    SECRET_NAME=$(terraform output -raw secret_name 2>/dev/null)
    if [ -z "$SECRET_NAME" ]; then
        echo "❌ Could not get secret name from Terraform output"
        echo "   Run 'terraform apply' first"
        exit 1
    fi
else
    echo "❌ terraform.tfstate not found"
    echo "   Run 'terraform apply' first"
    exit 1
fi

echo "Secret name: $SECRET_NAME"
echo ""

# Generate SSH key
KEY_NAME="secrets-demo-key"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

echo "1. Generating SSH key pair..."
if [ -f "$KEY_PATH" ]; then
    echo "⚠️  Key already exists at $KEY_PATH"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    rm -f "$KEY_PATH" "$KEY_PATH.pub"
fi

ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$KEY_NAME@secrets-manager" > /dev/null 2>&1

if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Key generation failed"
    exit 1
fi

echo "✅ SSH key generated:"
echo "   Private: $KEY_PATH"
echo "   Public:  $KEY_PATH.pub"
echo ""

# Read keys
PRIVATE_KEY=$(cat "$KEY_PATH")
PUBLIC_KEY=$(cat "$KEY_PATH.pub")

# Create JSON payload
echo "2. Creating secret payload..."
JSON_PAYLOAD=$(jq -n \
    --arg private_key "$PRIVATE_KEY" \
    --arg public_key "$PUBLIC_KEY" \
    --arg key_type "ed25519" \
    --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{
        private_key: $private_key,
        public_key: $public_key,
        key_type: $key_type,
        created_at: $created_at,
        description: "SSH key generated and managed by Terraform"
    }')

# Upload to Secrets Manager
echo "3. Uploading to AWS Secrets Manager..."
aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$JSON_PAYLOAD" \
    > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Secret uploaded successfully!"
else
    echo "❌ Failed to upload secret"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ Setup Complete!"
echo "========================================"
echo ""
echo "Private key location: $KEY_PATH"
echo "Public key location:  $KEY_PATH.pub"
echo ""
echo "Retrieve the secret:"
echo "  aws secretsmanager get-secret-value \\"
echo "    --secret-id $SECRET_NAME \\"
echo "    --query 'SecretString' \\"
echo "    --output text | jq -r '.private_key'"
echo ""
echo "Use in EC2 user-data:"
echo "  aws secretsmanager get-secret-value \\"
echo "    --secret-id $SECRET_NAME \\"
echo "    --query 'SecretString' \\"
echo "    --output text | jq -r '.private_key' > ~/.ssh/id_ed25519"
echo ""
echo "========================================"
