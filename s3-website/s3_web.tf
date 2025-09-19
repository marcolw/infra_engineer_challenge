terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "infra-terraform-state-20250910"  # Same bucket
    key            = "s3-website/terraform.tfstate"    # Different key
    region         = "ap-southeast-2"
    use_lockfile = true 
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-2"
  # us-east-1 provider for ACM certificate
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Static Website with CloudFront and HTTPS
resource "aws_s3_bucket" "website" {
  bucket = "marco-liao-website-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "website" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website,
    aws_s3_bucket_public_access_block.website,
  ]

  bucket = aws_s3_bucket.website.id
  acl    = "public-read"
}

# SSL Certificate for CloudFront (must be in us-east-1)
resource "aws_acm_certificate" "ssl_cert" {
  provider          = aws.us-east-1
  domain_name       = "s3.xeniumsolution.space"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# CloudFront Distribution
# CloudFront Distribution (CORRECTED)
resource "aws_cloudfront_distribution" "website" {
  origin {
    # CORRECTION: Use the regional S3 website endpoint format
    domain_name = "${aws_s3_bucket.website.bucket}.s3-website-ap-southeast-2.amazonaws.com"
    origin_id   = "S3-Website-${aws_s3_bucket.website.id}"

    # You MUST use custom_origin_config with website endpoints
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["s3.xeniumsolution.space"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Website-${aws_s3_bucket.website.id}"

    # Updated to use a managed cache policy (modern best practice)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed Policy: 'CachingOptimized'

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.ssl_cert.arn # This now works since cert is validated
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
}

# Website content
# resource "aws_s3_object" "site_files" {
#   for_each = fileset(path.module, "../site/**/*")
  
#   bucket       = aws_s3_bucket.website.id
#   key          = replace(each.value, "../site/", "")
#   source       = each.value
#   content_type = lookup({
#     ".html" = "text/html",
#     ".css"  = "text/css",
#     ".js"   = "application/javascript",
#     ".png"  = "image/png",
#     ".jpg"  = "image/jpeg",
#     ".svg"  = "image/svg+xml"
#   }, lower(regex("\\.[^.]+$", each.value)), "application/octet-stream")
  
#   acl = "public-read"
# }

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Marco Liao Website</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 { 
            color: #2c5282; 
            text-align: center;
        }
        .container {
            background: #f8f9fa;
            padding: 30px;
            border-radius: 10px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>This is Marco Liao's website</h1>
        <p>Infrastructure Engineering Challenge Solution</p>
        <p>Deployed with AWS S3 + CloudFront + Terraform</p>
        <p>✅ HTTPS enabled</p>
        <p>✅ Global CDN</p>
        <p>✅ Automated deployment</p>
    </div>
</body>
</html>
EOF
  content_type = "text/html"
  #acl          = "public-read"
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content      = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Page Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #e53e3e; }
    </style>
</head>
<body>
    <h1>Page Not Found</h1>
    <p><a href="/">Return to homepage</a></p>
</body>
</html>
EOF
  content_type = "text/html"
  acl          = "public-read"
}

# Outputs
output "website_url" {
  description = "S3 Website URL"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "cloudfront_url" {
  description = "CloudFront Distribution URL"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "cloudfront_domain" {
  description = "CloudFront Domain Name for DNS"
  value       = aws_cloudfront_distribution.website.domain_name
}