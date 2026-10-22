terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  cloud {}

  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.95.0"
    }
  }
}
