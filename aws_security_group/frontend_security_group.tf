resource "aws_security_group" "frontend" {
  vpc_id      = "${aws_vpc.dmz.id}"
  name        = "Frontend Security Group"
  description = "Frontend Security Group"

  tags { Name = "Frontend Security Group" }
}

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
