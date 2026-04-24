resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts"
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Triggers when CPU exceeds 80% for 4 minutes"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ombasa_asg.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = local.common_tags
}