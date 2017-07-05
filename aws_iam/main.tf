provider "aws" {
  # Seoul is ap-northeast-2 region
  region  = "ap-northeast-2"
}

resource "aws_iam_user" "devs" {
  count = "${length(var.dev_user_names)}"
  name  = "${element(var.dev_user_names, count.index)}"

  # force_destroy - (Optional, default false) When destroying this user, 
  # destroy even if it has non-Terraform-managed IAM access keys, 
  # login profile or MFA devices. Without force_destroy a user with 
  # non-Terraform-managed access keys and login profile will fail to be destroyed.
  force_destroy = true
}

resource "aws_iam_user_login_profile" "devs" {
  count                   = "${length(aws_iam_user.devs.*.name)}"
  user                    = "${element(aws_iam_user.devs.*.name, count.index)}"
  pgp_key                 = "${base64encode(file("iam.gpg.pubkey"))}"
  password_reset_required = true
}

resource "aws_iam_group" "devs" {
  name = "devs"
}

resource "aws_iam_group_policy" "devs" {
  name   = "iam_access_policy_for_dev"
	group  = "${aws_iam_group.devs.id}"
  policy = "${data.aws_iam_policy_document.devs.json}"
}

resource "aws_iam_group_membership" "devs" {
  name  = "devs_group_membership"
  users = ["${aws_iam_user.devs.*.name}"]
  group = "${aws_iam_group.devs.name}"
}
