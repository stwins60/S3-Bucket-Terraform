provider "aws" {
    region = "us-east-1"
}
resource "aws_s3_bucket" "cloudpros" {
   bucket = "cloudpros-static-website"
   acl = "public-read-write"

   website {
    index_document = "index.html"
    error_document = "error.html"
   }
    
   versioning {
      enabled = false
   }
   tags = {
     Name = "Bucket1"
     Environment = "Test"
   }
}




resource "aws_s3_bucket_object" "website_files" {
  for_each      = fileset(local.dir, "**/*.*")
  bucket        = aws_s3_bucket.cloudpros.id
  key           = replace(each.value, local.dir, "")
  source        = "${local.dir}${each.value}"
  acl           = "public-read"
  etag          = filemd5("${local.dir}${each.value}")
  content_type  = lookup(local.mime_types, split(".", each.value)[length(split(".", each.value)) - 1])
}

resource "aws_acm_certificate" "certificate" {
  domain_name       = "${var.root_domain_name}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [aws_s3_bucket_object.website_files,]
  origin {
    domain_name = "${aws_s3_bucket.cloudpros.bucket_regional_domain_name}"
    // domain_name = "${aws_s3_bucket.cloudpros.bucket.website_endpoint}"
    origin_id   = "${aws_s3_bucket.cloudpros.id}"
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3"
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.cloudpros.id}"
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
# Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${aws_s3_bucket.cloudpros.id}"
forwarded_values {
      query_string = false
      headers      = ["Origin"]
cookies {
        forward = "none"
      }
    }
min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
# Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.cloudpros.id}"
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  // aliases = ["${var.www_domain_name}"]
restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn = "${aws_acm_certificate.certificate.arn}"
    ssl_support_method = "sni-only"
  }
}


resource "aws_route53_zone" "route53_zone" {
  name = "${var.root_domain_name}"
}

resource "aws_route53_record" "www" {
  allow_overwrite = true
  name = "${var.www_domain_name}"
  ttl = 172800
  type = "NS"
  zone_id = "${aws_route53_zone.route53_zone.zone_id}"
  
  
  records = [
    aws_route53_zone.route53_zone.name_servers[0],
    aws_route53_zone.route53_zone.name_servers[1],
    aws_route53_zone.route53_zone.name_servers[2],
    aws_route53_zone.route53_zone.name_servers[3],
  ]

  

}

resource "aws_route53_record" "route53_zone" {
  zone_id = "${aws_route53_zone.route53_zone.zone_id}"
  name = "${var.root_domain_name}"
  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
    zone_id = "${aws_cloudfront_distribution.s3_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}


resource "aws_s3_bucket_policy" "cloudpros" {
  bucket = aws_s3_bucket.cloudpros.id

   policy = jsonencode({
    Version = "2012-10-17"
    Id      = "MYBUCKETPOLICY" 
    Statement = [
      {
        Sid       = "Stmt1630343692330"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.cloudpros.arn,
          "${aws_s3_bucket.cloudpros.arn}/*",
        ]
        Condition = {
          IpAddress = {
            "aws:SourceIp" = "8.8.8.8/32"
          }
        }

      },
    ]
  })
}



