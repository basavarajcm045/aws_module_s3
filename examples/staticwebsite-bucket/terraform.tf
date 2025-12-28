#========== BUCKET 4: Static Website Hosting ==========

data "aws_caller_identity" "current" {}

module "s3_website" {
  source = "../../modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_name   = "website-${data.aws_caller_identity.current.account_id}"
  region        = var.region
  force_destroy = true

  #------versioning and Basic security-----------#
  # versioning for rollbacks
  enable_versioning  = true
  versioning_enabled = true
  enable_mfa_delete  = false

  # Object lock for compliance
  enable_object_lock       = true
  object_lock_default_mode = "GOVERNANCE"
  object_lock_default_days = 30

  object_ownership = "BucketOwnerEnforced" # Disable ACLs
  // BucketOwnerPreferred

  # Encryption
  encryption_type    = "kms"
  kms_key_id         = "" # Auto-create KMS key
  bucket_key_enabled = true

  # Public read access for website content

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  enable_acls = false
  acl         = ""

  # Logging
  //enable_logging = true

  # Lifecycle for assets
  lifecycle_rules = [
    {
      id      = "delete-old-assets"
      enabled = true
      transitions = [
        {
          days          = 365
          storage_class = "GLACIER"
        }
      ]
      expiration = {
        days = 1825 # 5 years
      }
    }
  ]

  # Bucket Policy Settings
  enforce_ssl               = false 
  enforce_encrypted_uploads = false
  //enforce_public_read       = false

  # Website hosting configuration 
  enable_website_hosting        = true
  website_index_document        = "index.html"
  website_error_document        = "error.html"
  website_index_document_source = "../../web-content/"
  //website_redirect_all_requests_to = null
  //website_routing_rules = null

  #Monitoring & Alerts
  enable_cloudwatch_alarms = false

  # Intelligent Tiering
  enable_intelligent_tiering = false

  enable_metrics = true

  #===================== Tags =================#
  tags = {
    Team        = "Frontend"
    Environment = var.environment
    Project     = var.project_name
    Owner       = "Chris T"
    Purpose     = "Website"
    Region      = var.region
  }
}