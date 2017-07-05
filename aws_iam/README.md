**아래 원본 내용은 [이곳](https://rampart81.github.io/post/iam_config_terraform/)에서 볼수 있습니다.**

Terraform을 사용해서 IAM 계정을 설정하기 위해서 필요한 terraform `resource`들은  아래와 같다:

* aws_iam_user

* aws_iam_user_login_profile

* aws_iam_group

* aws_iam_group_policy

* aws_iam_group_membership

위의 `resource` 들을 설정해서 새로운 IAM 유저를 생성하고 login profile을 설정해주고 그룹과 그룹에 해당하는 접근 권한들을 설정한후 유저를 그룹에 추가해줄수 있다. 주로 IAM 계정들은 개발자들을 위해 생성해주는 경우가 많은데 개발자들에게 제한된 접근권한을 제공하는 경우가 많다. 그리고 많은 경우, 대부분의 개발자들은 동일하거나 비슷한 접근권한 (예를 들어 EC2 권한)을 제공받는 경우가 많다. 그럼으로 terraform을 이용하여 개발자 계정을 생성하기 위한 기본 틀을 설정해놓고 새로운 계정을 생성하거나 추가할때는 간단하게 유저 아이디를 추가하거나 삭제하면 되도록 만들수 있다.

먼저 `aws_iam_user` 을 설정하자. 

```terraform
resource "aws_iam_user" "devs" {
  count = "${length(var.dev_user_names)}"
  name  = "${element(var.dev_user_names, count.index)}"

  # force_destroy - (Optional, default false) When destroying this user, 
  # destroy even if it has non-Terraform-managed IAM access keys, 
  # login profile or MFA devices. Without force_destroy a user with 
  # non-Terraform-managed access keys and login profile will fail to be destroyed.
  force_destroy = true
}
```

리소스 이름은 dev로 했다 (모든 리소스의 이름은 편의상 dev로 할것이다). 여기서는 단순히 이름만 정해주면 되는데, 앞으로 생성될 유저의 이름은 알수 없으므로 변수로 설정해주어서 다른 곳에서 읽어들이도록 한다. `dev_user_names` 라는 변수는 리스트이고 유저 아이디 리스트 이다. 위의  `count = "${length(var.dev_user_names)}"` 는 이 `aws_iam_user` 리소스를 `dev_user_names` 리스트의 엘레멘트 수만큼 생성하라는 뜻이고 각 생성된 `aws_iam_user` 리소스의 `name`역시 `dev_user_names` 리스트에 포함되어 있는 이름으로 설정하게 된다. 예를 들어, `dev_user_names` 가 `['test1', 'test2', 'test2']` 라고 한다면 `aws_iam_user` 리소스가 3개가 생성이 되며 각각의 `name`은 'test1', 'test2', 그리고 'test3'가 된다. 

자 이제 `aws_iam_user_login_profile` 를 설정해주자. login profile을 설정해주어야 유저가 AWS 콘솔에 로그인 할수 있다. 

```terraform
resource "aws_iam_user_login_profile" "devs" {
  count                   = "${length(aws_iam_user.devs.*.name)}"
  user                    = "${element(aws_iam_user.devs.*.name, count.index)}"
  pgp_key                 = "${base64encode(file("iam.gpg.pubkey"))}"
  password_reset_required = true
}
```

여기서 중요한것은 `pgp_key` 인데 설정된 `pgp_key` 값을 가지고 비밀번호를 암호화 한다. 그래서 PGP key를 생성해서 설정해주어야 한다. GPG 키를 생성해서 설정해주도록 하자. GPG 키 자세한 생성법은 [이곳](https://help.github.com/articles/generating-a-new-gpg-key/)에 잘 나와있다. 대략 요약을 하자면:

1. 먼저 GPG 커맨드 라인 툴을 인스톨 한다 

```bash
brew instal gpg # mac 의 경우
```
2. GPG 키를 생성한다.

```bash
gpg --gen-key
```
3. GPG 키가 생성이 됬으면 아래 커맨드를 사용하여 생성된 GPG 키의 아이디를 확인한다.

```bash
gpg --list-secret-keys --keyid-format LONG
```
4. GPG 공개키값을 파일에 export 한다

```bash
gpg --export AF57729E > iam.gpg.pubkey
```

이제 `aws_iam_group` 설정을 하자. 간단하다. 그룹 이름만 정해주면 된다.
```terraform
resource "aws_iam_group" "devs" {
  name = "devs"
}
```

그리고 `aws_iam_group_policy` 설정을 하자. 
```terraform
resource "aws_iam_group_policy" "devs" {
  name   = "iam_access_policy_for_dev"
  group  = "${aws_iam_group.devs.id}"
  policy = "${data.aws_iam_policy_document.devs.json}"
}
```

`policy`는 inline으로 직접 설정할수도 있지만`data`로 따로 지정하는것이 좋다. 

```terraform
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
```
보는데로 AWS의 policy json과 설정이 동일하다 (다만 json이 아니고 테라폼의 document 포맷이니 주의하자). 

이제 `aws_iam_group_membership` 을 설정해주기만 하면 된다.

```terraform
resource "aws_iam_group_membership" "devs" {
  name  = "devs_group_membership"
  users = ["${aws_iam_user.devs.*.name}"]
  group = "${aws_iam_group.devs.name}"
}
```

이제 전체적은 설정은 되었다. 새로운 계정을 추가하기 위해서는 `dev_user_names` 변수만 지정해주면 된다.

```terraform
variable "dev_user_names" {
  description = "Developer user names for IAM"
  type        = "list"
  default     = []
}
```
예를 들어 `dev` 이라는 계정을 추가하고 싶다면 `default` 를 `default = ['dev1']`으로 바꿔주고 `terraform apply`를 실행시키면 된다.

마지막으로, `output`을 설정하여 새로 생성된 계정들의 비밀번호를 출력해야 한다.

```terraform
output "new_iam_user_password" {
  value = ["${aws_iam_user_login_profile.devs.*.encrypted_password}"]
}
```

출력되는 암호들은 GPG 키로 암호화된 암호들이므로 복호화 하는 것을 잊지말자.

```bash
terraform output new_iam_user_password | base64 --decode | keybase pgp decrypt.
```

