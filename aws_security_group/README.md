원본 post는 [이곳](https://rampart81.github.io/post/security_group_terraform/)에서 볼수 있다.



Seucrity Group(보안그룹) 은 하나 이상의 인스턴스에 대한 트래픽을 제어하는 가상 방화벽 이다. 이전 [post](https://rampart81.github.io/post/vpc_confing_terraform/) 에서는 VPC를 사용하여 큰그림의 전체적인 네트워크를 구현했다면 Security Group을 사용해서 더 세부적으로 (서버별로) 네트워크 트래픽을 제어할수 있다. Security Group을 사용하여 해당 인스턴스에 접속 할수 있는 소스 IP, Protocol 와 해당 인스턴스가 보낼수 있는 outbound 트래픽까지 설정할수 있다. 이전 [post](https://rampart81.github.io/post/vpc_confing_terraform/)에서 구현했던 네트워크 아키텍쳐를 기반으로 security group 아키텍쳐를 구현해보자.

## Security Group Architecture

![arch](https://rampart81.github.io/img/sg_diagram.png)

간단한 security group 구성이다. 아래와 같은 보안그룹 법칙이 적용되어 있다. 단순하고 간단한 예제 이지만 기본적인 보안 법칙, 즉 필요한 네트워크 트래픽만 허용하는 법칙은 적용하고 있다.

* Load Balancer Security Group은 public internet에서 HTTP 와 HTTPS 연결을 허용한다.
* Frontend Security Group은 Load Balancer Security Group에서만 HTTP 8080 연결만을 허용한다,
* Backend Security Group은 Frontend Security Group에서만 HTTP 8080 연결만을 허용한다

## 필요한 terraform resource들

위의 Security Group 아키텍쳐를 구현하기 위해서는 아래의 terraform resource들이 필요하다.

* [aws_security_group](https://www.terraform.io/docs/providers/aws/r/security_group.html) 
* [aws_security_group_rule](https://www.terraform.io/docs/providers/aws/r/security_group_rule.html)

## Steps

1 - Security Group들을 설정해준다.
```terraform
resource "aws_security_group" "frontend_load_balancer" {
  vpc_id      = "${aws_vpc.dmz.id}"
  name        = "Frontend Load Balancer Security Group"
  description = "Frontend Load Balancer Security Group"

  tags { Name = "Frontend Load Balancer Security Group" }
}

resource "aws_security_group" "frontend" {
  vpc_id      = "${aws_vpc.dmz.id}"
  name        = "Frontend Security Group"
  description = "Frontend Security Group"

  tags { Name = "Frontend Security Group" }
}

resource "aws_security_group" "application" {
  vpc_id      = "${aws_vpc.application.id}"
  name        = "Application Security Group"
  description = "Application Security Group"

  tags { Name = "Application Security Group" }
}


```
* Security Group을 설정해주는건 간단하다. 해당 Security Group이 속할 VPC 를 지정해주고 이름, 설명, 그리고 tag(optional)을 지정해 주면 된다.
* 아래에서 더 자세히 설명하겠지만, `aws_security_group`에서 inline rule을 정의 할수도 있다. 하지만 inline rule을 적용하면 제약사항이 몇가지 생기니 inline rule을 적용하지 말고 `aws_security_group_rule` resource를 사용하여 따로 rule을 지정해주도록 하자.

2 - 각 Security Group들마다 Security Group Rule을 적용해준다.
```terraform
## Load Balancer Security Group Rules
resource "aws_security_group_rule" "frontend_lb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.frontend_load_balancer.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "frontend_lb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.frontend_load_balancer.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "frontend_lb_http_egress" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.frontend_load_balancer.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "frontend_lb_https_egress" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.frontend_load_balancer.id}"

  lifecycle { create_before_destroy = true }
}
```

```terraform
## Frontend Security Group Rules
resource "aws_security_group_rule" "frontend_http_lb_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.frontend.id}"
  source_security_group_id = "${aws_security_group.frontend_load_balancer.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "frontend_http_lb_egress" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.frontend_ec2.id}"
  source_security_group_id = "${aws_security_group.frontend_load_balancer.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "frontend_http_application_egress" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.frontend.id}"
  source_security_group_id = "${aws_security_group.application.id}"

  lifecycle { create_before_destroy = true }
}
```

```terraform
## Application Security Group Rules
resource "aws_security_group_rule" "application_http_frontend_ingress" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.application.id}"
  source_security_group_id = "${aws_security_group.frontend.id}"

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group_rule" "application_http_frontend_egress" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "TCP"
  security_group_id        = "${aws_security_group.application.id}"
  source_security_group_id = "${aws_security_group.frontend.id}"

  lifecycle { create_before_destroy = true }
}
```
* `aws_security_group_rule` resource를 사용하여 각 security group에 필요한 rule들을 지정해준다. 
* inboud 트레픽은 "ingress", outbound 트레픽은 "egress"로 타입을 지정해준다
* `source_security_group_id` 이외에도 `cidr_blocks` 를 사용하여 소스 IP 주소 범위를 지정해 줄수 있다. 둘중 하나만 지정해줘야 하며 둘다 지정할수는 없다. 지정된 security group이 있다면 `source_security_group_id`를 사용하고 그게 아니라면 `cidr_blocks`를 사용해서 소스 IP 주소를 지정해 주면 된다.
* AWS 콘솔에서 securty group을 생성하면 All Allowed Outbound Traffic을 자동으로 생성해주지만 terraform에서는  All Allowed Outbound Traffic를 default로 설정해주지 않는다. 이건 좋은 컨벤션인거 같다. Outbound도 필요한 포트와 소스만 허용하는것이 좋다. 

## Pro Tips
* `aws_security_group` resource는 inline으로 rule을 지정해줄수도 있도록 하고 있지만 inline rule을 사용하면 2가지 제한이 있다.
  * 위의 경우 처럼 security group간의 dependency가 있는 경우 inline rule을 사용하게 되면 cycle dependency 에러가 발생한다. 예를 들어, security group A를 생성하기 위해서는 security group B의 id가 필요한데 security group B를 생성하기 위해서는 security group A id가 필요한 상황이 cycle dependency의 경우이다. 이를 해결하기 위햐서는 `aws_security_group` resource를 사용하여 security group들을 먼저 생성한후 `aws_security_group_rule` resource를 사용해여 rule들을 지정해주야 한다. 실제로 security group을 terraform에서 생성할때 cycle dependency 에러가 많은 유저들에게 큰 문제가 되었고 이를 해결하기 위해 `aws_security_group_rule` resource가 생겨나게 되었다. 이와 관한 더 자세한 내용은 [이곳](https://github.com/hashicorp/terraform/issues/539)에서 볼수 있다.
  * Cycle dependency 문제가 없다고 하더라도, inline rule을 사용하면 `aws_security_group_rule`을 사용할수 없게 된다. 즉 두가지중 하나만 사용해야 하는 것인데, inline rule을 사용하면 다른 환경에 따라 같은 security group에 다른 rule을 적용할수 없게 된다. Terraform을 사용할때 공통적으로 사용되는 resource들은 공통 module로 만든 후 환경 (예를 들어, staging vs production)에 맞추어 다른 설정을 하게 되는게 일반적인데, inline rule을 사용하게 되면 그렇게 할수 없게 된다. Terraform 코드 구조에 대해서는 다음에 자세히 설명하도록 하겠다. 
* AWS는 VPC마다 default security group을 자동으로 생성한다. `aws_default_security_group` resource를 사용하면 default security group들 설정도 가능하다. 이미 생성되어 있는 security group이고 지울수도 없으니(AWS가 default security group의 삭제를 허용하지 않는다) 낭비하지 말고 사용할수 있으면 좋겠지만 문제는 현재 버젼의 terraform에서는 `aws_default_security_group`은 `aws_security_group_rule`을 사용할수 없고 오직 inline rule만 허용된다. 그럼으로 다른 security group id에 의존하는 rule이 있다면 cycle dependency 에러가 발생할수 있는 문제가 있다.
