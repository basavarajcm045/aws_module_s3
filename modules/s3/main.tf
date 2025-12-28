#========== Local Variables ==========

locals {
  bucket_prefix = "${var.project_name}-${var.environment}"
  
  enable_bucket_policy = (
    var.enforce_encrypted_uploads ||
    var.enforce_ssl 
  )

  # Default tags
  default_tags = merge(
    var.tags,
    {
      Module      = "S3"
      ManagedBy   = "Terraform"
    }
  )
}

#========== Random Suffix (only used when bucket_name is not provided) ==========
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

#========== S3 Bucket ==========#

resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name != "" ? var.bucket_name : "${local.bucket_prefix}-${random_string.bucket_suffix.result}"
  
  lifecycle {
    prevent_destroy = false
  }

  force_destroy = var.force_destroy
  
  tags = merge(
    local.default_tags,
    {
      Name = var.bucket_name != "" ? var.bucket_name : "${local.bucket_prefix}-${random_string.bucket_suffix.result}"

    }
  )
}

#========== Bucket Versioning ==========#

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
    mfa_delete = var.enable_versioning && var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

#========== OBJECT LOCK ==========

resource "aws_s3_bucket_object_lock_configuration" "main" {
  count = var.enable_object_lock ? 1 : 0
  #count  = var.enable_object_lock && var.object_lock_default != null ? 1 : 0
  bucket = aws_s3_bucket.main.id

  rule {
    default_retention {
      mode = var.object_lock_default_mode
      days = try(var.object_lock_default_days, null)
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

#=========BUCKET OWNERSHIP ==========

resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    object_ownership = var.object_ownership
  }
}
#========== ENCRYPTION ==========

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      
      sse_algorithm      = var.encryption_type == "kms" ? "aws:kms" : "AES256"
      kms_master_key_id  = var.encryption_type == "kms" && var.kms_key_id != "" ? var.kms_key_id : null
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

#========== PUBLIC ACCESS BLOCK ==========

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

#========== ACL ==========

resource "aws_s3_bucket_acl" "main" {
  count  = var.enable_acls ? 1 : 0
  bucket = aws_s3_bucket.main.id
  acl    = var.acl

  depends_on = [aws_s3_bucket_public_access_block.main]
}

#========== LIFECYCLE CONFIGURATION ==========

resource "aws_s3_bucket_lifecycle_configuration" "main" {

  #Create this resource only if lifecycle_rules is not empty
  for_each = length(var.lifecycle_rules) > 0 ? toset([ "enabled" ]) : []

  bucket = aws_s3_bucket.main.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      # Filtering
      dynamic "filter" {
        for_each = rule.value.filters != null ? [rule.value.filters] : []
        content {
          and {
            prefix = try(filter.value.prefix, "")
            tags   = try(filter.value.tags, {})
          }
        }
      }

      # Transitions
      dynamic "transition" {
        #for_each = rule.value.transitions != null ? rule.value.transitions : []
        for_each = try(rule.value.transition, [])
        #for_each = try(rule.value.transitions, null) != null ? [rule.value.transitions] : []
        content {
          days          = try(transition.value.days, null)
          #date          = try(transition.value.date, null)
          storage_class = transition.value.storage_class
          #storage_class = try(transition.value.storage_class, null)
        }
      }

      # Expiration
      dynamic "expiration" {
        for_each = try(rule.value.expiration, null) != null ? [rule.value.expiration] : []
        content {
          days                         = try(expiration.value.days, null)
          date                         = try(expiration.value.date, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }
      
      # Noncurrent version transitions
      dynamic "noncurrent_version_transition" {
        for_each = try(rule.value.noncurrent_version_transition, [])
        content {
          noncurrent_days = noncurrent_version_transition.value.noncurrent_days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      # Noncurrent version expiration
      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration, null) != null ? [rule.value.noncurrent_version_expiration] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value.noncurrent_days
        }
      }
      
      # Abort incomplete multipart upload
      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_upload, null) != null ? [rule.value.abort_incomplete_multipart_upload] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value.days_after_initiation
        }
      }

    }
  }
    
  depends_on = [aws_s3_bucket_versioning.main]
}

#========== BUCKET POLICY ==========

resource "aws_s3_bucket_policy" "main" {
  count  = local.enable_bucket_policy ? 1 : 0
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(

      # Deny unencrypted uploads
      #DENIES any object upload to the bucket unless the object is encrypted at rest
      #It enforces server-side encryption (SSE) on all PutObject operations.
      #https://aws.amazon.com/premiumsupport/knowledge-center/s3-require-encryption-upload/
      
      var.enforce_encrypted_uploads ? [
        {
          Sid    = "DenyUnencryptedObjectUploads"
          Effect = "Deny"
          Principal = "*"
          Action = ["s3:PutObject"]
          Resource = "${aws_s3_bucket.main.arn}/*"
          Condition = {
            StringNotEquals = {
              "s3:x-amz-server-side-encryption" = var.encryption_type == "kms" ? "aws:kms" : "AES256"
            }
            Null = {
              "s3:x-amz-server-side-encryption" = "true"
            }
            //StringNotEquals = {
              //"s3:x-amz-server-side-encryption" = "AES256"
            //}

          }
        }

        #only if you are enforcing KMS key only
       /* {
          Sid    = "DenyUnencryptedObjectUploadsKMS"
          Effect = "Deny"
          Principal = "*"
          Action = ["s3:PutObject"]
          Resource = "${aws_s3_bucket.main.arn}/*"
          Condition = {
            StringNotEquals = {
              "s3:x-amz-server-side-encryption" = "aws:kms"
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_id != "" ? var.kms_key_id : aws_kms_key.s3[0].arn
            }
            StringNotEqualsIfExists = {
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = "aws_kms_key.my_key_arn"
            }
            Null = {
              "s3:x-amz-server-side-encryption-aws-kms-key-id" = "true"
              "s3:x-amz-server-side-encryption" = "true"
            }
          }
        }*/

      ] : [],

       
      # Deny insecure transport (HTTP)
      # DENIES any request to the bucket that is not using secure transport (HTTPS).
      var.enforce_ssl ? [
        {
          Sid    = "DenyInsecureTransport"
          Effect = "Deny"
          Principal = "*"
          //Action = "s3:*"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.main.arn,
            "${aws_s3_bucket.main.arn}/*"
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = "false"
            }
          }
        }
      ] : [],

      # Allow specific principals if provided
      /*var.allow_principals != {} ? [
        for principal, permissions in var.allow_principals : {
          Sid       = "AllowPrincipal${replace(principal, "/[^A-Za-z0-9]/", "")}"
          Effect    = "Allow"
          Principal = contains(keys(permissions), "arn") ? { AWS = permissions.arn } : { Service = permissions.service }
          Action    = permissions.actions
          Resource = contains(keys(permissions), "include_bucket_resource") && permissions.include_bucket_resource ? [
            aws_s3_bucket.main.arn,
            "${aws_s3_bucket.main.arn}/*"
          ] : ["${aws_s3_bucket.main.arn}/*"]
          Condition = contains(keys(permissions), "condition") ? permissions.condition : null
        }
      ] : [],
      */
      /*var.allow_principals != {} ? [
        for principal, permissions in var.allow_principals : merge(
          {
            Sid       = "Allow${replace(principal, "/[^A-Za-z0-9]/", "")}"
            Effect    = "Allow"
            Principal = contains(keys(permissions), "arn") ? { AWS = permissions.arn } : { Service = permissions.service }
            Action   = permissions.actions
            Resource = contains(keys(permissions), "include_bucket_resource") && permissions.include_bucket_resource ? concat(
                  ["${aws_s3_bucket.main.arn}"],
                  ["${aws_s3_bucket.main.arn}/*"]
                
            ) : ["${aws_s3_bucket.main.arn}/*"]
          },
          contains(keys(permissions), "condition")
            ? { Condition = permissions.condition }
            : {}
        )
      ] : []*/
      # Custom policy statements
      //var.custom_policy_statements
    )
  })
}

#========== WEBSITE HOSTING ==========

resource "aws_s3_bucket_website_configuration" "main" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.main.id
  index_document {
    suffix = var.website_index_document
    
  }
  error_document {
    key = var.website_error_document
    
  } 

  /*routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }*/

}

resource "aws_s3_object" "main" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.main.id
  key    = var.website_index_document
  source = var.website_index_document_source
  acl    = "public-read"
  content_type = "text/html"
  
}

#========== INTELLIGENT TIERING ==========

resource "aws_s3_bucket_intelligent_tiering_configuration" "main" {
  count  = var.enable_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = "AutoArchive"

  status = "Enabled"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_archive_days
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = var.intelligent_tiering_deep_archive_days
  }
}
#========== REQUEST METRICS ==========

/*resource "aws_s3_bucket_metric" "entire_bucket" {
  count  = var.enable_metrics ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = "EntireBucket"
}

resource "aws_s3_bucket_metric" "by_storage_class" {
  count  = var.enable_metrics ? 1 : 0
  bucket = aws_s3_bucket.main.id
  name   = "ByStorageClass"

  filter {
    and {
      prefix = ""
      tags   = {}
    }
  }
}*/


#========== MONITORING & ALARMS ==========
# This resource can also created as part CloudWatch module.
# Refer readme for more details.

resource "aws_cloudwatch_metric_alarm" "bucket_size" {
  
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.bucket_name}-bucket-size-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = 86400
  statistic           = "Maximum"
  threshold           = var.bucket_size_threshold_bytes
  alarm_description   = "Alert when bucket size exceeds threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.main.id
    StorageType = "StandardStorage"
  }
}

resource "aws_cloudwatch_metric_alarm" "object_count" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.bucket_name}-object-count-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = 86400
  statistic           = "Maximum"
  threshold           = var.object_count_threshold
  alarm_description   = "Alert when number of objects exceeds threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.main.id
    StorageType = "AllStorageTypes"
  }
}





