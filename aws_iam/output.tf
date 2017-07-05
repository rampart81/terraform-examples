output "new_iam_user_password" {
  value = ["${aws_iam_user_login_profile.devs.*.encrypted_password}"]
}
