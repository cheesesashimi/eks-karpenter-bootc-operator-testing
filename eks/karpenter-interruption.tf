# ------------------------------------------------------------------------------
# Karpenter Interruption Handling
# ------------------------------------------------------------------------------
resource "aws_sqs_queue" "karpenter_interruption" {
  name                       = var.cluster_name
  message_retention_seconds  = 300
  visibility_timeout_seconds = 30

  tags = {
    Name                     = "${var.cluster_name}-interruption"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-spot-interruption"
  description = "Forward EC2 spot interruption warnings to Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_rule" "instance_rebalance" {
  name        = "${var.cluster_name}-instance-rebalance"
  description = "Forward EC2 rebalance recommendations to Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    "detail-type" = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.cluster_name}-instance-state-change"
  description = "Forward EC2 state changes to Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["stopping", "stopped"]
    }
  })
}

resource "aws_cloudwatch_event_rule" "health_event" {
  name        = "${var.cluster_name}-health-event"
  description = "Forward AWS Health events to Karpenter"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "instance_rebalance" {
  rule = aws_cloudwatch_event_rule.instance_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule = aws_cloudwatch_event_rule.instance_state_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "health_event" {
  rule = aws_cloudwatch_event_rule.health_event.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridgeSendMessage"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.karpenter_interruption.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = [
            aws_cloudwatch_event_rule.spot_interruption.arn,
            aws_cloudwatch_event_rule.instance_rebalance.arn,
            aws_cloudwatch_event_rule.instance_state_change.arn,
            aws_cloudwatch_event_rule.health_event.arn
          ]
        }
      }
    }]
  })
}
