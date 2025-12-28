
#========== BUCKET: Backup Bucket - Read-Only Replica ==========#
data "aws_caller_identity" "current" {}

module "s3_backup" {
  source = "../../modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_name   = "myapp-backup-${data.aws_caller_identity.current.account_id}"
  region        = var.region
  force_destroy = true

  #------versioning and Basic security-----------#

  # Immutable for backup protection
  enable_versioning  = true
  versioning_enabled = true
  enable_mfa_delete  = false

  # Object Lock for immutability
  enable_object_lock       = true
  object_lock_default_mode = "GOVERNANCE"
  object_lock_default_days = 30

  object_ownership = "BucketOwnerEnforced" # Disable ACLs
  
  # Encryption
  encryption_type    = "kms"
  kms_key_id         = ""
  bucket_key_enabled = false

  # Deny all public access

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  enable_acls = false
  acl         = ""

  # Minimal lifecycle to clean incomplete uploads

  lifecycle_rules = [
    {
      id      = "clean-incomplete-uploads"
      enabled = true
      #prefix  = "backups/"

      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }
    }
  ]

  # Bucket Policy Settings
  enforce_ssl               = true
  enforce_encrypted_uploads = true
  //enforce_public_read       = true

  #Static website hosting

  enable_website_hosting        = false
  website_index_document        = "index.html"
  website_error_document        = "error.html"
  website_index_document_source = "web-content/"

  # Inventory for audit
  #enable_inventory = true

  # Intelligent Tiering
  enable_intelligent_tiering            = false

  # CloudWatch monitoring
  enable_cloudwatch_alarms = false

  enable_metrics = true

  #===================== Tags =================#

  tags = {
    Team        = "Infrastructure"
    Environment = var.environment
    Project     = var.project_name
    Owner       = "Chris T"
    Purpose     = "Backup"
    Criticality = "High"
    region      = var.region
  }
}
#========== END BUCKET: Backup Bucket - Read-Only Replica ==========#