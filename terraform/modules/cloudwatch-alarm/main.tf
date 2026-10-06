# ============================================================
# cloudwatch-alarm module — main.tf
# ============================================================

# ----------------------------------------------------------------
# Locals — SNS ARNs fed to every alarm action
# ----------------------------------------------------------------
locals {
  all_action_arns = var.notification.existing_sns_topic_arns == null ? [] : [var.notification.existing_sns_topic_arns]
}

# ================================================================
# CloudWatch Metric Alarms
# ================================================================
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms

  alarm_name        = each.key
  alarm_description = each.value.alarm_description
  namespace         = length(try(each.value.metric_queries, [])) == 0 ? each.value.namespace : null
  metric_name       = length(try(each.value.metric_queries, [])) == 0 ? each.value.metric_name : null
  dimensions        = length(try(each.value.metric_queries, [])) == 0 ? each.value.dimensions : null

  # Threshold
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator

  # Period / evaluation
  period              = length(try(each.value.metric_queries, [])) == 0 ? each.value.period : null
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm != null ? each.value.datapoints_to_alarm : each.value.evaluation_periods

  # Statistic — use extended_statistic (e.g. p99) when provided, else plain statistic
  statistic          = length(try(each.value.metric_queries, [])) == 0 && each.value.extended_statistic == null ? each.value.statistic : null
  extended_statistic = length(try(each.value.metric_queries, [])) == 0 ? each.value.extended_statistic : null

  dynamic "metric_query" {
    for_each = try(each.value.metric_queries, [])
    iterator = mq
    content {
      id          = mq.value.id
      expression  = try(mq.value.expression, null)
      label       = try(mq.value.label, null)
      return_data = try(mq.value.return_data, false)
  
      dynamic "metric" {
        for_each = mq.value.metric != null ? [mq.value.metric] : []
        iterator = m
        content {
          namespace   = m.value["namespace"]
          metric_name = m.value["metric_name"]
          period      = m.value["period"]
          stat        = m.value["stat"]
          unit        = try(m.value["unit"], null)
          dimensions  = try(m.value["dimensions"], null)
        }
      }
    }
  }

  # Missing data behaviour
  treat_missing_data = each.value.treat_missing_data

  # Notifications
  alarm_actions = local.all_action_arns
  ok_actions    = each.value.ok_actions_enabled ? local.all_action_arns : []

  tags = merge(var.tags, { Name = each.key })
}
