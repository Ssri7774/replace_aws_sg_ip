#!/bin/bash

# Check if profile argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <aws-profile>"
  echo "Example: $0 profile1"
  exit 1
fi

AWS_PROFILE="$1"
# Replace these variables with your actual values
OLD_IP="14.201.181.110/32"  # Your old office IP with CIDR notation

# Define arrays for new IPs and their descriptions
declare -a NEW_IPS=("103.67.56.208/32" "103.67.56.226/32")
declare -a DESCRIPTIONS=("8c-HQ-35" "8c-HQ-37")

AWS_REGION="ap-northeast-1"  # Your AWS region

# Get AWS account number
ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query "Account" --output text)

# Function to get current timestamp
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

echo "[$(get_timestamp)] Starting security group update"
echo "[$(get_timestamp)] Profile: $AWS_PROFILE | Account: $ACCOUNT_ID | Region: $AWS_REGION"

# Get all security groups
echo "[$(get_timestamp)] Fetching security groups..."
SECURITY_GROUPS=$(aws ec2 describe-security-groups --region $AWS_REGION --profile $AWS_PROFILE --query "SecurityGroups[*].GroupId" --output text)

for SG_ID in $SECURITY_GROUPS; do
  echo "[$(get_timestamp)] Processing security group: $SG_ID (Account: $ACCOUNT_ID, Region: $AWS_REGION)"
  
  # Get ingress rules that match the old IP
  RULES=$(aws ec2 describe-security-groups --region $AWS_REGION --profile $AWS_PROFILE --group-ids $SG_ID \
    --query "SecurityGroups[0].IpPermissions[?contains(IpRanges[].CidrIp, '$OLD_IP')]" --output json)
  
  # Check if we found any matching rules
  if [ $(echo $RULES | jq length) -gt 0 ]; then
    echo "[$(get_timestamp)] Found matching rules in $SG_ID, updating..."
    
    # Process each matching permission
    echo $RULES | jq -c '.[]' | while read -r RULE; do
      FROM_PORT=$(echo $RULE | jq -r '.FromPort // "all"')
      TO_PORT=$(echo $RULE | jq -r '.ToPort // "all"')
      PROTOCOL=$(echo $RULE | jq -r '.IpProtocol')
      
      # Revoke old rule
      if [ "$FROM_PORT" != "all" ] && [ "$TO_PORT" != "all" ]; then
        echo "[$(get_timestamp)] Revoking rule for ports $FROM_PORT-$TO_PORT, protocol $PROTOCOL (Account: $ACCOUNT_ID, Region: $AWS_REGION)"
        aws ec2 revoke-security-group-ingress --region $AWS_REGION --profile $AWS_PROFILE --group-id $SG_ID \
          --protocol $PROTOCOL --port $FROM_PORT-$TO_PORT --cidr $OLD_IP
      else
        echo "[$(get_timestamp)] Revoking rule for protocol $PROTOCOL (all ports) (Account: $ACCOUNT_ID, Region: $AWS_REGION)"
        aws ec2 revoke-security-group-ingress --region $AWS_REGION --profile $AWS_PROFILE --group-id $SG_ID \
          --protocol $PROTOCOL --cidr $OLD_IP
      fi
      
      # Add new rules for each IP with its description
      for i in "${!NEW_IPS[@]}"; do
        NEW_IP="${NEW_IPS[$i]}"
        RULE_DESCRIPTION="${DESCRIPTIONS[$i]}"
        
        if [ "$FROM_PORT" != "all" ] && [ "$TO_PORT" != "all" ]; then
          echo "[$(get_timestamp)] Adding rule for $NEW_IP ($RULE_DESCRIPTION) ports $FROM_PORT-$TO_PORT, protocol $PROTOCOL"
          aws ec2 authorize-security-group-ingress --region $AWS_REGION --profile $AWS_PROFILE --group-id $SG_ID \
            --ip-permissions "[{\"IpProtocol\": \"$PROTOCOL\", \"FromPort\": $FROM_PORT, \"ToPort\": $TO_PORT, \"IpRanges\": [{\"CidrIp\": \"$NEW_IP\", \"Description\": \"$RULE_DESCRIPTION\"}]}]"
        else
          echo "[$(get_timestamp)] Adding rule for $NEW_IP ($RULE_DESCRIPTION) protocol $PROTOCOL (all ports)"
          aws ec2 authorize-security-group-ingress --region $AWS_REGION --profile $AWS_PROFILE --group-id $SG_ID \
            --ip-permissions "[{\"IpProtocol\": \"$PROTOCOL\", \"IpRanges\": [{\"CidrIp\": \"$NEW_IP\", \"Description\": \"$RULE_DESCRIPTION\"}]}]"
        fi
      done
    done
  else
    echo "[$(get_timestamp)] No matching rules found in $SG_ID (Account: $ACCOUNT_ID, Region: $AWS_REGION)"
  fi
done

echo "[$(get_timestamp)] Security group update completed for profile $AWS_PROFILE in account $ACCOUNT_ID, region $AWS_REGION!"
