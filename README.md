# Security Group IP Replacement Tool

## Overview
This script automates the process of updating AWS security group rules by replacing an old IP address with multiple new IP addresses across all security groups in a specified AWS region. It's particularly useful when your office IP addresses change and you need to update all security group rules that reference the old IP.

## Features
- Scans all security groups in the specified AWS region
- Identifies rules that contain the old IP address
- Preserves the original protocol and port configurations
- Adds a description to each new rule for better identification
- Works with both port-specific rules and protocol-only rules (like ICMP)
- Provides detailed logging with account ID, region, and timestamps
- Supports multiple new IP addresses with individual descriptions

## Prerequisites
- AWS CLI installed and configured
- jq installed (for JSON parsing)
- Appropriate AWS permissions to describe, revoke, and authorize security group rules

## Usage
```bash
./update_security_groups.sh <aws-profile>
```

### Example
```bash
./update_security_groups.sh production
```

### Example with Logging
```bash
./update_security_groups.sh <aws-profile> | tee -a output.log
```

This command runs the script with the specified AWS profile and saves all output to a log file while also displaying it in the terminal. This is particularly useful for:
- Keeping a record of all changes made to security groups
- Troubleshooting issues that might occur during execution
- Auditing purposes to track when and what changes were made
- Having a reference of which security groups were updated with timestamps

## Configuration
Edit the following variables in the script to match your requirements:

```bash
OLD_IP="1.2.3.4/32"  # Your old office IP with CIDR notation

# Define arrays for new IPs and their descriptions
declare -a NEW_IPS=("5.6.7.8/32" "9.8.7.6/32")
declare -a DESCRIPTIONS=("office1" "office2")

AWS_REGION="ap-northeast-1" # Your AWS region
```

## How It Works
1. The script fetches all security groups in the specified region
2. For each security group, it identifies rules that contain the old IP address
3. It extracts the protocol and port information from each matching rule
4. It revokes the old rule and creates new rules with each of the new IP addresses
5. The new rules maintain the same protocol and port configuration as the old rule
6. Each new rule includes a specific description for easier identification
7. All operations are logged with timestamps, account ID, and region information

## Notes
- The script requires the AWS profile name as a command-line argument
- It will only update rules that exactly match the specified old IP address
- Each new IP address will have its own description as specified in the DESCRIPTIONS array
- The enhanced logging includes AWS account ID and region for better clarity

## Security Considerations
- Always verify the changes after running the script
- Consider running with limited permissions to prevent unintended modifications
- Back up your security group configurations before making bulk changes
