# Account-regional namespace: the name must end in -<account>-<region>-an, and S3
# only accepts it from that account. No global name collisions, and a bucket can
# never be created in the wrong account.
resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_145:SSE-S3 encrypts the state. A customer key adds cost and a way to lock the state out.
  #checkov:skip=CKV_AWS_144:One region by SCP. Versioning is the recovery path.
  #checkov:skip=CKV_AWS_18:Access logs need a second bucket. The bucket policy and Block Public Access are the control here.
  #checkov:skip=CKV2_AWS_62:Nothing consumes events from a state bucket.
  bucket           = var.bucket_name
  bucket_namespace = "account-regional"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is what makes a corrupted or deleted state recoverable.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  #checkov:skip=CKV_AWS_300:State files are small single-part uploads, so no multipart upload is left to abort.
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
