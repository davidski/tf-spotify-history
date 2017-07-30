variable "aws_region" {
  default = "us-west-2"
}

variable "aws_profile" {
  description = "Name of AWS profile to use for API access."
  default     = "default"
}

variable "vpc_cidr" {
  description = "CIDR for build VPC"
  default     = "192.168.0.0/16"
}

variable "project" {
  description = "Default value for project tag."
  default     = "spotify"
}

variable "client_id" {
  description = "PySpotify OAuth client ID."
}

variable "client_secret" {
  description = "PySpotify OAuth client secret."
}

variable "bucket_key" {
  description = "Location of Spotify history files and token file in S3."
  default     = "data"
}
