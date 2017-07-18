resource "aws_security_group" "frontend_load_balancer" {
  vpc_id      = "${aws_vpc.dmz.id}"
  name        = "Frontend Load Balancer Security Group"
  description = "Frontend Load Balancer Security Group"

  tags { Name = "Frontend Load Balancer Security Group" }
}

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


