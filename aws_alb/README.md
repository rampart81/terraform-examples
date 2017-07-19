원문 포스트는 [이곳](https://rampart81.github.io/post/lb_terraform/)에서 볼수 있다.


AWS에서 제공하는 load balancer 서비스에는 2가지가 있는데 ALB(Application Load Balancer)와 ELB(Elastic Load Balancer)이다. 예전에는 AWS에서 ELB만 제공했었다. ELB는 굉장히 기본적인 load balancing 기능 밖에 제공하지 않았다. 예를 들어 url path에 따라 routing을 하는 기능 같은 것은 제공되지 않아서 많은 유저들이 ELB를 쓰지 않고 nginx나 HAProxy 등을 직접 운영하는 경우도 많았었다. ELB의 부족한 기능을 보완한것이 ALB이다. Url path 기반의 routing을 할수도 있고 최근에는 host-based routing 기능도 추가되었다. Terraform을 사용하여 ALB 설정을 구현해보자.

## Load Balancer Diagram

![arch](https://rampart81.github.io/img/alb.png)

ALB를 Route 53 dns 서비스를 사용하여 custom domain과 연결시켜서 외부에서는 custom domain을 사용하여 ALB에 접속하도록 한다. 또한 AWS Certificate Manager를 사용하여 SSL certificate을 생성해서 ALB에 설정하여 외부에서 HTTPS로 접속이 가능하도록 한다. 또한 S3와 연결시켜서 ALB의 트래픽 로그가 S3 버켓에 저장되도록 설정할것이다. 마지막으로 url path 기반의 routing을 적용하여 `/static` 으로 오는 request 들은 static 리소스 전용 서버로 보내도록 한다. 

## 필요한 terraform resource들

* [aws_alb](https://www.terraform.io/docs/providers/aws/r/alb.html)
* [aws_alb_target_group](https://www.terraform.io/docs/providers/aws/r/alb_target_group.html)
* [aws_alb_target_group_attachment](https://www.terraform.io/docs/providers/aws/r/alb_target_group_attachment.html)
* [aws_alb_listener](https://www.terraform.io/docs/providers/aws/r/alb_listener.html)
* [aws_alb_listener_rule](https://www.terraform.io/docs/providers/aws/r/alb_listener_rule.html)
* [aws_route53_record](https://www.terraform.io/docs/providers/aws/r/route53_record.html)
* [aws_route53_zone](https://www.terraform.io/docs/providers/aws/r/route53_zone.html)
* [aws_s3_bucket](https://www.terraform.io/docs/providers/aws/r/s3_bucket.html)
* [aws_acn_cerfificate](https://www.terraform.io/docs/providers/aws/d/acm_certificate.html)

## Steps

1 - ALB 를 생성한다

```terraform
resource "aws_alb" "frontend" {
  name            = "alb-example"
  internal        = false
  security_groups = ["${aws_security_group.frontend_lb.id}"]
  subnets         = [
    "${aws_default_subnet.dmz_public_1a.id}",
    "${aws_default_subnet.dmz_public_1c.id}"
  ]

  access_logs {
    bucket  = "${aws_s3_bucket.alb.id}"
    prefix  = "frontend-alb"
    enabled = true
  }

  tags {
    Name = "ALB Example"
  }


  lifecycle { create_before_destroy = true }
}
```

* 편의상 `security_groups`와 `subnets`는 저번 post에서 설정했던 `security_groups`와 `subnet` 사용한다.
* `access_logs` 옵션을 통하여 ALB log를 S3 버켓에 저장하도록 한다. 이 기능을 설정하기 위해서는 당연히 해당 S3 버켓이 이미 존재 해야한다. ALB 로그 저장용 S3 버켓 설정은 아래에 있다.
* `lifecycle`은 `create_before_destroy`를 true로 설정해서 만일 ALB가 재생성되어야 한다면 새로운 ALB를 먼저 생성후 예전 ALB를 지우도록 한다. 이렇게 함으로 ALB 재생성으로 인한 downtime이 없도록 한다.

0 - ALB 로그를 저장할 S3를 설정한다

```terraform
resource "aws_s3_bucket" "alb" {
  bucket = "alb-log-example.com"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.alb_account_id}:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::alb-log-example.com/*"
    }
  ]
}
  EOF

  lifecycle_rule {
    id      = "log_lifecycle"
    prefix  = ""
    enabled = true

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

* `poloicy` 옵션을 통해 ALB가 S3 버켓에 로그를 저장할수 있는 permission을 제공한다. 주의해야 할점은 `policy`에서 `Principal` 필드에 ALB 계정 아이디를 설정해야 하는데, 각 리전마다 ALB의 계정 아이디가 틀리다. 예를 들어 서울 리젼의 ALB 계정 아이디는 "600734575887"이다. variable `alb_account_id`에 ALB 계정 아이디를 설정해주면 된다. 각 리전별 ALB 계정 아이디는 [이곳](http://docs.aws.amazon.com/elasticloadbalancing/latest/classic/enable-access-logs.html)에서 확인할수 있다.
* `lifecycle_rule` 옵션을 통해 오래된 로그파일 관리를 설정한다. 위의 예제에서는 로그파일이 30일이 지나면 `GLACIER` storage로 옴기고 90일이 지나면 삭제하도록 설정하였다.

2 - ALB 타겟 그룹을 설정한다

```terraform
resource "aws_alb_target_group" "frontend" {
  name     = "frontend-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_default_vpc.dmz.id}"

  health_check {
    interval            = 30
    path                = "/ping"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags { Name = "Frontend Target Group" }
}

resource "aws_alb_target_group" "static" {
  name     = "static-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_default_vpc.dmz.id}"

  health_check {
    interval            = 30
    path                = "/ping"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags { Name = "Static Target Group" }
}

resource "aws_alb_target_group_attachment" "frontend" {
  target_group_arn = "${aws_alb_target_group.frontend.arn}"
  target_id        = "${aws_instance.frontend.id}"
  port             = 8080
}

resource "aws_alb_target_group_attachment" "static" {
  target_group_arn = "${aws_alb_target_group.static.arn}"
  target_id        = "${aws_instance.static.id}"
  port             = 8080
}

```

* 2개의 타겟 그룹을 설정한다. 하나는 일반적인 트래픽을 처리할 타겟그룹 이며 다른 하나는 static 리소스 request 전용 타겟 그룹이다.

* `health_check` 설정에 따라 ALB가 연결된 instance들의 상태를 체크해서 다운된 instance는 routing에서 제외한다. 위의 경우, 30초에 한번씩 health check를 하게 되어 있으며 `/ping` 으로 health check request를 보내게 된다.  만일 3번 연속으로 health check가 실패할경우 서버가 다운되었다고 간주한다. 마찬가지로 다운되었던 서버가 3번 연속으로 health check에 성공하면 다시 routing에 포함된다.

* `aws_alb_target_group_attachment` 리소스를 설정해서 각 타겟 그룹에 서버들을 포함시킨다. 타겟 그룹에 포함된 서버들로 ALB가 request들을 전달하며, 하나 이상의 서버의 경우가 포함됬을 경우 round-robin으로 routing한다. 위의 경우 편의상 각 타겟 그룹별로 하나의 서버만 포함시켰지만 대부분의 경우 하나 이상의 서버를 포함 시키게 된다. 그러한 경우 `target_id`에 instance id가 아닌 ECS container id를 설정할수도 있다. 다만 안타깝께도 현재 ECS는 서울 리젼에서는 아직 서비스화 되지 않았다. 다른 방법은 `count`와 `element`를 사용하여 여러 서버를 포함시킬수 있다:

  ```terraform
  resource "aws_alb_target_group_attachment" "frontend" {
    count            = "${var.ec2_frontend_instance_count}"
    target_group_arn = "${aws_alb_target_group.frontend.arn}"
    target_id        = "${element(aws_instance.frontend.*.id, count.index)}"
    port             = 8080
  }
  ```
```


3 - ALB listener를 설정한다

​```terraform
data "aws_acm_certificate" "example_dot_com"   { 
  domain   = "*.example.com."
  statuses = ["ISSUED"]
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.example_dot_com.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.frontend.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = "${aws_alb.frontend.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.frontend.arn}"
    type             = "forward"
  }
}
```

* `aws_alb_listener`는 HTTP와 HTTPS를 각각 따로 설정해주어야 한다. 그래서 총 2개의 `aws_alb_listener`를 설정한다.
* HTTPS listener를 설정할때는 HTTPS를 처리할수 있도록 `ssl_poliyc`와 `certificate_arn`을 설정해줘야 한다. `certificate_arn`은 AWS Certification Manager를 통해서 생성한 SSL Cerfitication의 ARN을 지정해주면 된다. 참고로 현재는 Terraform을 통해서 AWS Certification Manager을 설정할수 없다. 그래서 직접 AWS 콘솔을 통해서 설정을 해야하며, 설정이 된 이후에는 `aws_acm_certificate` data를 통해 terraform상에서 설정을 읽어들일수 있다.
* `default_action`은 한마디로 default listener rule이다. 즉 따로 지정된 listener rule이 없거나 해당된 listener rule이 없다면 `default_action`에 설정된 rule을 ALB가 실행한다. `default_action`은 단순히 타겟 그룹에 request를 forward해주는것 이외에 다른 설정은 할 수 없다.

4 - ALB listener rule을 설정한다

```terraform
resource "aws_alb_listener_rule" "static" {
  listener_arn = "${aws_alb_listener.https.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.static.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/static/*"]
  }
}
```

* `aws_alb_listener_rule`을 설정하여 `/static` 으로 오는 request들은 static 타겟 그룹에 속해있는 서버들에게 보낸다. 
* `condition`옵션을 통해서 url path 패턴을 설정할수 있다. 만일 `/static`이 아니라 `/public`으로 설정하고 싶다면 `condition`의 `values` 값을 변경해주면 된다. `values`는 리스트 값을 받으므로 한 개 이상의 path를 지정해줄수도 있다.

5 - Route53 DNS 통하여 custom domain을 설정한다.

```terraform
resource "aws_route53_zone" "example" {
  name = "example.com."
}

resource "aws_route53_record" "frontend_A" {
  zone_id = "${data.aws_route53_zone.example.zone_id}"
  name    = "example.com"
  type    = "A"

  alias {
    name     = "${aws_alb.frontend.dns_name}"
    zone_id  = "${aws_alb.frontend.zone_id}"
  }
}
```

* `aws_route53_zone` 리소스로 해당 도매인의 route53 zone을 생성한다. 당연한거지만 해당 도매인은 실제로 소유하고 있어야 한다. 
* `aws_route53_record` 리소스 설정을 통해서 A record를 생성한다. 위의 경우 `example.com`을 위에 생성한 ALB에 연결시켰다. ALB를 A record 생성하려먼  `alias` 설정을 해주어야 한다. `alias`설정은 위의 나온대로 단순히 ALB dns name과 zone id만 설정해주면 된다. 

## Pro Tips

* ALB 로그를 저장하기 위한 S3 버켓은 ALB와 같은 리젼에 위치해 있어야 한다. 그럼으로 동일한 리젼에서 생성하도록 하자. 리젼 설정은 S3 버켓 설정에서 `region` 옵션을 설정해 줄수도 있지만, 만일 따로 설정을 안하면 terraform이 자동으로 현재 리젼에서 생성한다.
* ALB 설정이 여러 resource들을 같이 설정해줘야 하기 때문에 다소 복잡할수도 있다. 한꺼번에 다 설정하는것 보다 한번에 하나씩 설정하는것을 권장한다. 한가지 설정을 한후 `terraform plan`으로 확인하고 `terraform apply`로 실행시킨후 문제가 없으면 그 다음 설정을 실행하는것이 실수를 줄일수 있다.
