package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestFullStackEndToEnd(t *testing.T) {
	t.Parallel()

	uniqueID := strings.ToLower(random.UniqueId())

	appOptions := &terraform.Options{
		TerraformDir:    "github.com/SOIGWA/Ombasa-terraform.io//modules/services/webserver-cluster?ref=feature/phase3-automation",
		TerraformBinary: "terraform",
		Vars: map[string]interface{}{
			"cluster_name":       fmt.Sprintf("test-app-%s", uniqueID),
			"vpc_name":           fmt.Sprintf("test-vpc-%s", uniqueID),
			"environment":        "dev",
			"use_existing_vpc":   false,
			"active_environment": "blue",
		},
	}

	defer terraform.Destroy(t, appOptions)

	terraform.InitAndApply(t, appOptions)

	albDnsName := terraform.Output(t, appOptions, "alb_dns_name")
	targetUrl := fmt.Sprintf("http://%s", albDnsName)

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		targetUrl,
		nil,
		60,
		10*time.Second,
		func(statusCode int, body string) bool {
			return statusCode == 200 && strings.Contains(body, "Hello, World V2")
		},
	)
}
