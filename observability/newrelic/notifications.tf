# Destino, canal e workflow de notificação são opcionais e parametrizados.
# Sem notification_enabled a validação estática continua funcionando sem
# depender de ids reais da conta New Relic.

locals {
  notification_created = local.count_enabled == 1 && var.notification_enabled && var.notification_email != ""
  notification_count   = local.notification_created ? 1 : 0
}

resource "newrelic_notification_destination" "email" {
  count = local.notification_count

  account_id = var.newrelic_account_id
  name       = "${local.name}-email"
  type       = "EMAIL"
  active     = true

  property {
    key   = "email"
    value = var.notification_email
  }
}

resource "newrelic_notification_channel" "email" {
  count = local.notification_count

  account_id     = var.newrelic_account_id
  name           = "${local.name}-email"
  type           = "EMAIL"
  destination_id = one(newrelic_notification_destination.email[*].id)
  product        = "IINT"

  property {
    key   = "subject"
    value = "[{{ priority }}] Oficina ${var.environment}: {{ issueTitle }}"
  }
}

resource "newrelic_workflow" "main" {
  count = local.notification_count

  account_id            = var.newrelic_account_id
  name                  = "${local.name}-workflow"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "${local.name}-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [local.policy_id]
    }
  }

  destination {
    channel_id = one(newrelic_notification_channel.email[*].id)
  }
}
