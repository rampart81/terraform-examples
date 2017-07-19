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
