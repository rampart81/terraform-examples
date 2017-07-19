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

resource "aws_alb_target_group_attachment" "frontend" {
	count            = "${var.ec2_frontend_instance_count}"
	target_group_arn = "${aws_alb_target_group.frontend.arn}"
	target_id        = "${element(aws_instance.frontend.*.id, count.index)}"
	port             = 8080
}

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
