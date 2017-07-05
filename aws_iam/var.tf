variable "dev_user_names" {
  description = "Developer user names for IAM"
  type        = "list"
  default     = []
}

data "aws_iam_policy_document" "devs" {
  # EC2 Full Access
	statement {
		actions = [
			"ec2:*",
			"elasticloadbalancing:*",
			"cloudwatch:*",
			"autoscaling:*"		
		],
		effect    = "Allow",
		resources = ["*"]
	}

  # RDS Full Access
	statement {
		actions = [
			"rds:*",
			"cloudwatch:DescribeAlarms",
			"cloudwatch:GetMetricStatistics",
			"ec2:DescribeAccountAttributes",
			"ec2:DescribeAvailabilityZones",
			"ec2:DescribeSecurityGroups",
			"ec2:DescribeSubnets",
			"ec2:DescribeVpcs",
			"sns:ListSubscriptions",
			"sns:ListTopics",
			"logs:DescribeLogStreams",
			"logs:GetLogEvents"
		],
		effect    = "Allow",
		resources = ["*"]
	}

	# S3 Full Access
	statement {
		actions   = ["s3:*"],
		effect    = "Allow",
		resources = ["*"]
	}

	# CloudWatch Full Access
	statement {
		actions = [
			"autoscaling:Describe*",
			"cloudwatch:*",
			"logs:*",
			"sns:*"
		],
		effect    = "Allow",
		resources = ["*"]
	}

}
