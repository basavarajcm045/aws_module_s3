variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "test", "ppe", "prod"], var.environment)
    error_message = "Invalid environment. Allowed values are: dev, test, ppe, prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format (e.g., us-east-1, eu-west-1)."
  }
}

variable "bucket_name" {
  description = "S3 bucket name (if empty, a unique name will be generated)"
  type        = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.bucket_name))
    )

    error_message = "Bucket name must be 3–63 characters, lowercase, and contain only letters, numbers, dots, and hyphens."
  }

}

variable "force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket so that the buxket can be destroyed without error"
  type        = bool
  
  validation {
    condition = (
      var.environment != "prod" ||
      var.force_destroy == false
    )

    error_message = "force_destroy must be false in prod environments."
  }
}

#=======Versioning Variables ========
variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  
}

variable "versioning_enabled" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for the S3 bucket (requires versioning to be enabled)"
  type        = bool
  
}

#=======Object Lock==============

variable "enable_object_lock" {
  description = "Enable S3 Object Lock at bucket creation (force new if changed to true)"
  type        = bool
}

variable "object_lock_default_mode" {
  description = "Default object lock mode: GOVERNANCE or COMPLIANCE"
  type        = string
}

variable "object_lock_default_days" {
  description = "Default retention period (days) for object lock"
  type        = number
}

#variable "object_lock_default_years" {
  #description = "Default retention period (Year/s) for object lock"
  #type        = number
  #default     = 1
#}

/*variable "object_lock_custom_retention" {
  description = "Custom retention settings for object lock"
  type        = list(object({
    prefix         = string
    mode           = string
    retain_days    = optional(number)
    retain_until_date = optional(string)
  }))
  default     = []
  
}*/

#=============Bucket Ownership Controls ========

variable "object_ownership" {
  description = "Bucket ownership controls for the S3 bucket (ObjectWriter or BucketOwnerPreferred)"
  type        = string
  
}

#=============Public Access Block & ACL Variables ========

variable "block_public_acls" {
  description = "Block public ACLs for the S3 bucket"
  type        = bool
  
}

variable "block_public_policy" {
  description = "Block public bucket policies for the S3 bucket"
  type        = bool
  
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs for the S3 bucket"
  type        = bool
  
}

variable "restrict_public_buckets" {
  description = "Restrict public buckets for the S3 bucket"
  type        = bool
  
}

variable "enable_acls" {
  description = "Enable ACLs for the S3 bucket"
  type    = bool
  
}

variable "acl" {
description = "Canned ACL to apply to the S3 bucket"
  type        = string
  default     = ""
  
}

#=======Lifecycle Rules Variables ========

variable "lifecycle_rules" {
  description = "Lifecycle rules for the S3 bucket"

  type = list(object({
    id      = string
    enabled = bool

    # ------ FILTERS ------
    filters = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))

    # ------ TRANSITIONS ------
    transitions = optional(list(object({
      days          = optional(number)
      date          = optional(string)
      storage_class = string
    })))

    noncurrent_version_transitions = optional(list(object({
      noncurrent_days = number
      storage_class   = string
    })))

    # ------ EXPIRATION ------
    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))

    noncurrent_version_expiration = optional(object({
      noncurrent_days = number
    }))

    # ------ ABORT ------
    abort_incomplete_multipart_upload = optional(object({
      days_after_initiation = number
    }))
  }))

  default = []
}
#=======Bucket Policy======

/*variable "enable_bucket_policy" {
  description = "Enable bucket policy for the S3 bucket"
  type        = bool
  
}*/
variable "enforce_encrypted_uploads" {
  description = "Enforce encrypted uploads to the S3 bucket"
  type        = bool
  
}

variable "enforce_ssl" {
  description = "Enforce SSL for requests to the S3 bucket"
  type        = bool 
  
}

/*variable "enforce_public_read" {
  description = "Enforce public read access to the S3 bucket"
  type        = bool 
  
}*/

#========Encryption Variables ========

variable "encryption_type" {
  description = "Type of encryption for the S3 bucket (none, sse-s3, kms)"
  type        = string

  validation {
    condition     = contains(["aes256", "kms"], var.encryption_type)
    error_message = "encryption_type must be either 'aes256' or 'kms'."
  }
}

variable "kms_key_id" {
  description = "KMS Key ID for KMS encryption (if null, AES256 will be used)"
  type        = string
  default     = ""
}

variable "bucket_key_enabled" {
  description = "Enable S3 Bucket Key for KMS encryption"
  type        = bool
  
}

#===============

/*variable "allow_principals" {
  type = map(object({
    arn                     = string
    actions                 = list(string)
    include_bucket_resource = bool
  }))
}*/

/*variable "custom_policy_statements" {
  type    = list(any)
  default = []
}*/

variable "enable_metrics" {
  description = "Enable S3 bucket metrics"
  type        = bool
  
}
#========= Static Website Hosting Variables ========

variable "enable_website_hosting" {
  description = "Enable static website hosting for the S3 bucket"
  type        = bool
  
}

variable "website_index_document" {
  description = "Index document for static website hosting"
  type        = string
  
}   

variable "website_error_document" {
  description = "Error document for static website hosting"
  type        = string
  
} 

variable "website_index_document_source" {
  description = "Source file for index document"
  type        = string  
  
}

/*variable "website_error_document_source" {
  description = "Source file for error document"
  type        = string  
  
}

variable "website_redirect_all_requests_to" {
  description = "Redirect all requests to another host name"
  type        = string
  
}

variable "website_routing_rules" {
  description = "Routing rules for static website hosting"
  type        = string
  
}*/

#========Intelligent Tiering Variables ========

variable "enable_intelligent_tiering" {
  description = "Enable Intelligent Tiering for the S3 bucket"
  type        = bool
  
}

variable "intelligent_tiering_archive_days" {
  description = "Number of days before moving objects to Intelligent Tiering Archive"
  type        = number
  default     = null
}

variable "intelligent_tiering_deep_archive_days" {
  description = "Number of days before moving objects to Intelligent Tiering Deep Archive"
  type        = number
  default     = null
}

#=======Tags Variables ========
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      contains(keys(var.tags), "Owner"),
      contains(keys(var.tags), "Project"),
      contains(keys(var.tags), "Environment")
    ])

    error_message = "Tags must include owner, project, and environment."
  }
}

#=========Monitoring Variables ========

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch Alarms for S3 bucket"
  type        = bool
  default     = false
}

variable "bucket_size_threshold_bytes" {
  description = "Bucket size threshold in bytes for CloudWatch Alarm"
  type        = number
  default     = null

  validation {
    condition = (
      var.enable_cloudwatch_alarms == false ||
      var.bucket_size_threshold_bytes != null
    )

    error_message = "bucket_size_threshold_bytes must be set when CloudWatch alarms are enabled."
  }

}

variable "object_count_threshold" {
  description = "Object count threshold for CloudWatch Alarm"
  type        = number
  default     = null

  validation {
    condition = (
      var.enable_cloudwatch_alarms == false ||
      var.object_count_threshold != null
    )

    error_message = "object_count_threshold must be set when CloudWatch alarms are enabled."
  }
  
}

