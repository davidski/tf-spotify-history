provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"

  assume_role {
    role_arn = "arn:aws:iam::754135023419:role/administrator-service"
  }
}

# Data source for the availability zones in this zone
data "aws_availability_zones" "available" {}

# Data source for current account number
data "aws_caller_identity" "current" {}

# Data source for main infrastructure state
data "terraform_remote_state" "main" {
  backend = "s3"

  config {
    bucket  = "infrastructure-severski"
    key     = "terraform/infrastructure.tfstate"
    region  = "us-west-2"
    encrypt = "true"
  }
}

/*
  --------------
  | S3 Bucket |
  --------------
*/

# S3 location for spotify data files
resource "aws_s3_bucket" "spotify" {
  bucket = "spotify-severski"

  logging {
    target_bucket = "${data.terraform_remote_state.main.auditlogs}"
    target_prefix = "s3logs/spotify-severski/"
  }

  logging {
    target_bucket = "${data.terraform_remote_state.main.auditlogs}"
    target_prefix = "s3logs/spotify-severski/"
  }

  tags {
    Name       = "Spotify data files"
    project    = "${var.project}"
    managed_by = "Terraform"
  }
}

/*
  -------------
  | IAM Roles |
  -------------
*/

resource "aws_iam_role" "lambda_worker" {
  name_prefix = "spotify-history"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid = "2"

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]

    resources = ["arn:aws:s3:::*"]
  }
}

resource "aws_iam_policy" "policy" {
  name   = "lambda_spotify_history"
  path   = "/"
  policy = "${data.aws_iam_policy_document.policy.json}"
}

resource "aws_iam_role_policy_attachment" "lambda_worker" {
  role       = "${aws_iam_role.lambda_worker.id}"
  policy_arn = "${aws_iam_policy.policy.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_worker_logs" {
  role       = "${aws_iam_role.lambda_worker.id}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

output "lambda_role_arn" {
  value = "${aws_iam_role.lambda_worker.arn}"
}

/*
  ----------------------------
  | Schedule Lambda Function |
  ----------------------------
*/

resource "aws_cloudwatch_event_rule" "default" {
  name                = "spotify_trigger"
  description         = "Trigger Spotify History Lambda on a periodic basis"
  schedule_expression = "rate(2 hours)"
}

resource "aws_cloudwatch_event_target" "default" {
  rule      = "${aws_cloudwatch_event_rule.default.name}"
  target_id = "TriggerSpotifyHistory"
  arn       = "${aws_lambda_function.spotify_history.arn}"
}

resource "aws_lambda_permission" "from_cloudwatch_events" {
  statement_id  = "AllowExecutionFromCWEvents"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.spotify_history.arn}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.default.arn}"
}

resource "aws_lambda_function" "spotify_history" {
  s3_bucket     = "artifacts-severski"
  s3_key        = "lambdas/spotify-history.zip"
  function_name = "spotify_history"
  role          = "${aws_iam_role.lambda_worker.arn}"
  handler       = "main.lambda_handler"
  description   = "Update Spotify played tracks hsitory"
  runtime       = "python3.6"
  timeout       = 10

  environment {
    variables = {
      SPOTIFY_CLIENT_ID     = "${var.client_id}"
      SPOTIFY_CLIENT_SECRET = "${var.client_secret}"
      SPOTIFY_BUCKET_NAME   = "${aws_s3_bucket.spotify.id}"
      SPOTIFY_BUCKET_PATH   = "${var.bucket_key}"
    }
  }

  tags {
    project    = "${var.project}"
    managed_by = "Terraform"
  }
}
