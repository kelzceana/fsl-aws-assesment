#s3 bucket
resource "aws_s3_bucket" "fsl_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "fsl bucket"
    Environment = var.env
  }
}

#s3 bucket for logs
resource "aws_s3_bucket" "cloudfront_logs_bucket" {
  bucket = "${var.bucket_name}-cloudfront-logs"

  tags = {
    Name        = "fsl logs"
    Environment = var.env
  }
}

#bucket ownership
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs_ownership" {
  bucket = aws_s3_bucket.cloudfront_logs_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs_pab" {
  bucket = aws_s3_bucket.cloudfront_logs_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs_ownership]
}

resource "aws_s3_bucket_policy" "fsl_bucket_policy" {
  bucket = aws_s3_bucket.fsl_bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.fsl_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_acl" "cloudfront_logs_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.cloudfront_logs_ownership,
    aws_s3_bucket_public_access_block.cloudfront_logs_pab
    ]

  bucket = aws_s3_bucket.cloudfront_logs_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_website_configuration" "fsl_bucket_wc" {
  bucket = aws_s3_bucket.fsl_bucket.id

  index_document {
    suffix = "index.html"
  }

}

#cloudfront
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

#cloudfront with logging
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.fsl_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-${aws_s3_bucket.fsl_bucket.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs_bucket.bucket_domain_name
    prefix          = "cloudfront-logs/${var.env}/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.fsl_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      
    }
  }

  tags = {
    Environment = var.env
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  depends_on = [
    aws_s3_bucket_acl.cloudfront_logs_acl
  ]
}

resource "aws_s3_bucket_policy" "cloudfront_logs_bucket_policy" {
  bucket = aws_s3_bucket.cloudfront_logs_bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontLogging"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.cloudfront_logs_bucket.arn,
          "${aws_s3_bucket.cloudfront_logs_bucket.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_acl.cloudfront_logs_acl]
}
