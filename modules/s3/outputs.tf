#========== BUCKET INFORMATION ==========

output "bucket_id" {
  description = "S3 bucket ID/name"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.main.arn
}
##
output "bucket_region" {
  description = "S3 bucket region"
  value       = aws_s3_bucket.main.region
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

#========== VERSIONING & LOCK ==========

output "bucket_versioning" {
  description = "The bucket versioning status"
  value       = aws_s3_bucket_versioning.main.versioning_configuration[0].status
}

output "versioning_enabled" {
  description = "Whether versioning is enabled"
  value       = var.enable_versioning
}

output "mfa_delete_enabled" {
  description = "Whether MFA delete is enabled"
  value       = var.enable_mfa_delete
}

output "object_lock_enabled" {
  description = "Whether object lock is enabled"
  value       = var.enable_object_lock
}

#========== ENCRYPTION ==========

output "encryption_type" {
  description = "Bucket encryption type"
  value       = var.encryption_type
}

/*output "kms_key_id" {
  description = "KMS key ID (if using KMS encryption)"
  //value       = var.encryption_type == "kms" ? (var.kms_key_id != "" ? var.kms_key_id : try(aws_kms_key.s3[0].id, "")) : null
  value = var.encryption_type != "kms" ? null :
    (
      var.kms_key_id != "" ? var.kms_key_id :
      length(aws_kms_key.s3) > 0 ? aws_kms_key.s3[0].id : null
    )
  sensitive   = true
}*/

/*output "kms_key_arn" {
  description = "KMS key ARN (if using KMS encryption)"
  value       = var.encryption_type == "kms" ? (var.kms_key_id != "" ? "arn:aws:kms:*:*:key/${var.kms_key_id}" : try(aws_kms_key.s3[0].arn, "")) : null
  sensitive   = true
}*/
  
#========== SECURITY ==========

output "public_access_blocked" {
  description = "Whether public access is blocked"
  value       = {
    block_public_acls       = var.block_public_acls
    block_public_policy     = var.block_public_policy
    ignore_public_acls      = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets
  }
}

output "ssl_enforced" {
  description = "Whether SSL/TLS is enforced"
  value       = var.enforce_ssl
}

#========== LIFECYCLE CONFIGURATION ==========

output "lifecycle_rules_count" {
  description = "Number of lifecycle rules configured"
  value       = length(var.lifecycle_rules)
}

output "lifecycle_rules_summary" {
  description = "Summary of lifecycle rules"
  value = [
    for rule in var.lifecycle_rules : {
      id      = rule.id
      enabled = rule.enabled
      prefix  = try(rule.prefix, "")
    }
  ]
}

#==========Bucket Policy ==========

output "bucket_policy_settings" {
  description = "Bucket policy enforcement settings"
  value = {
    enforce_encrypted_uploads = var.enforce_encrypted_uploads
    enforce_ssl               = var.enforce_ssl
    //enforce_public_read       = var.enforce_public_read
  }
}

#==========Website Configuration ==========

output "website_hosting_enabled" {
  description = "Whether website hosting is enabled"
  value       = aws_s3_bucket_website_configuration.main != null ? true : false
}

output "website_endpoint" {
  description = "S3 bucket website endpoint"
  value = length(aws_s3_bucket_website_configuration.main) > 0 ? aws_s3_bucket_website_configuration.main[0].website_endpoint : ""
  # value = try(
  #   aws_s3_bucket_website_configuration.main[0].website_endpoint,""
  # )
}

#========== Intelligent Tiering ==========
output "intelligent_tiering_enabled" {
  description = "Whether intelligent tiering is enabled"
  value       = var.enable_intelligent_tiering
}

#========== Monitoring & Alarms ==========

output "cloudwatch_alarms_enabled" {
  description = "Whether CloudWatch alarms are enabled"
  value       = var.enable_cloudwatch_alarms
}

#========== TAGS ==========
output "bucket_tags" {
  description = "Tags assigned to the S3 bucket"
  value       = aws_s3_bucket.main.tags
}
