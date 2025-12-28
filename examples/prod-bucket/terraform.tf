#==============BUCKET: Development Bucket - Minimum security and compliance===========#

#=============BUCKET: Production Bucket - Maximum security and compliance =============#

data "aws_caller_identity" "current" {}

module "s3_dev" {
  source = "../../modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_name   = var.bucket_name
  region        = var.region
  force_destroy = true

  #------versioning and Basic security-----------#

  enable_versioning  = true # make it true to enable versioning
  versioning_enabled = true # make it true to enable versioning
  enable_mfa_delete  = false

  # Object lock for compliance
  enable_object_lock       = true
  object_lock_default_mode = "GOVERNANCE"
  object_lock_default_days = 30        

  #acl = "private"

  object_ownership = "BucketOwnerEnforced" # Disable ACLs

  # Encryption
  //encryption_type     = "sse-s3"
  encryption_type    = "kms"
  kms_key_id         = "" # Auto-create KMS key
  bucket_key_enabled = true

  #Block all public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  enable_acls = false
  acl         = ""

  # Comprehensive logging
  //enable_logging   = true
  //log_prefix       = "audit-logs/"
  //log_retention_days = 2555  # 7 years for compliance

  # Lifecycle - Archive after 60 days
  lifecycle_rules = [
    {
      id      = "object-archieve"
      enabled = true

      filter = {
        prefix = "logs/"
        tags = {
          "archive" = "true"
        }
      }

      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 60, storage_class = "GLACIER" },
        { days = 90, storage_class = "DEEP_ARCHIVE" }

      ]

      expiration = {
        days = 365 # 1 years
      }

      noncurrent_version_transition = [
        {
          noncurrent_days = 7
          storage_class   = "GLACIER"
        }
      ]

      noncurrent_version_expiration = {
        noncurrent_days = 365
      }

      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }

    }
  ]

  # Bucket Policy Settings
  enforce_ssl               = true # Allow non-SSL for dev
  enforce_encrypted_uploads = true
  //enforce_public_read       = false

  # Policy for EC2 instances to access
  /*allow_principals = {
    "ec2-app-role" = {
      arn                     = "arn:aws:iam::123456789012:role/ec2-app-role"
      actions                 = ["s3:GetObject", "s3:PutObject"]
      include_bucket_resource = false
    }
  }*/

  #Static website hosting

  enable_website_hosting        = false
  website_index_document        = "index.html"
  website_error_document        = "error.html"
  website_index_document_source = "web-content/"

  #Monitoring & Alerts
  enable_cloudwatch_alarms = false

  # Intelligent Tiering
  enable_intelligent_tiering            = false
  
  enable_metrics = true

  #===================== Tags =================#

  tags = {
    Team        = "Engineering"
    Environment = var.environment
    Project     = var.project_name
    Owner       = "Chris T" 
    CostCenter  = var.cost_center
    Compliance  = "GDPR HIPAA"
    Region      = var.region
  }
}

#========== BUCKET 4: Static Website Hosting ==========

/*module "s3_website" {
  source = "./modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_name   = "website-${data.aws_caller_identity.current.account_id}"
  region = var.region
  force_destroy = true

  #------versioning and Basic security-----------#
  # versioning for rollbacks
  enable_versioning  = true # make it true to enable versioning
  versioning_enabled = true # make it true to enable versioning
  enable_mfa_delete  = false

  # Object lock for compliance
  enable_object_lock       = true
  object_lock_default_mode = "GOVERNANCE"
  object_lock_default_days = 30
  #object_lock_default_years = 7 

  object_ownership = "BucketOwnerEnforced" # Disable ACLs

  # Encryption
  encryption_type    = "kms"
  kms_key_id         = "" # Auto-create KMS key
  bucket_key_enabled = true

  # Public read access for website content
  //acl = "public-read"
  block_public_acls         = false
  block_public_policy       = false
  ignore_public_acls        = false
  restrict_public_buckets   = false
  enforce_ssl               = false
  enforce_encrypted_uploads = false
  enforce_public_read       = true

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

  # Website hosting configuration 
  enable_website_hosting        = true
  website_index_document        = "index.html"
  website_error_document        = "error.html"
  website_index_document_source = "web-content/"
  //website_redirect_all_requests_to = null
  //website_routing_rules = null

  #Monitoring & Alerts
  enable_cloudwatch_alarms = false

  enable_metrics = true

  tags = {
    Team        = "Frontend"
    Environment = var.environment
    Project     = var.project_name
    Owner       = "Chris T" 
    Purpose     = "Website"
    region      = var.region
  }
}*/