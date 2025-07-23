package test

import (
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Test the main Terraform configuration
func TestTerraformMainConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../terraform",
		NoColor:      true,
		BackendConfig: map[string]interface{}{
			"path": "terraform.tfstate.test",
		},
	}

	// Clean up after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and validate
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}

// Test MetalLB module
func TestMetalLBModule(t *testing.T) {
	t.Parallel()

	moduleDir := filepath.Join("..", "..", "terraform", "modules", "metallb")

	terraformOptions := &terraform.Options{
		TerraformDir: moduleDir,
		NoColor:      true,
		Vars: map[string]interface{}{
			"ip_range":  "10.0.0.200-10.0.0.210",
			"pool_name": "test-pool",
			"namespace": "metallb-test",
		},
	}

	// Validate the module
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)

	// Test variable validation
	t.Run("InvalidIPRange", func(t *testing.T) {
		invalidOptions := &terraform.Options{
			TerraformDir: moduleDir,
			NoColor:      true,
			Vars: map[string]interface{}{
				"ip_range": "invalid-ip-range",
			},
		}

		// This should fail validation
		_, err := terraform.InitE(t, invalidOptions)
		assert.NoError(t, err) // Init should succeed

		_, err = terraform.ValidateE(t, invalidOptions)
		assert.Error(t, err) // Validation should fail
	})
}

// Test Traefik module
func TestTraefikModule(t *testing.T) {
	t.Parallel()

	moduleDir := filepath.Join("..", "..", "terraform", "modules", "traefik")

	terraformOptions := &terraform.Options{
		TerraformDir: moduleDir,
		NoColor:      true,
		Vars: map[string]interface{}{
			"nodeport_http":      30080,
			"nodeport_https":     30443,
			"nodeport_dashboard": 30900,
		},
	}

	// Validate the module
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}

// Test Harbor module
func TestHarborModule(t *testing.T) {
	t.Parallel()

	moduleDir := filepath.Join("..", "..", "terraform", "modules", "harbor")

	terraformOptions := &terraform.Options{
		TerraformDir: moduleDir,
		NoColor:      true,
		Vars: map[string]interface{}{
			"admin_password": "TestPassword123",
			"storage_size":   "5Gi",
			"nodeport":       30880,
		},
	}

	// Validate the module
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
}

// Test variable validation
func TestVariableValidation(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name      string
		vars      map[string]interface{}
		shouldErr bool
	}{
		{
			name: "ValidConfiguration",
			vars: map[string]interface{}{
				"server_ip":       "10.0.0.88",
				"metallb_ip_range": "10.0.0.200-10.0.0.210",
			},
			shouldErr: false,
		},
		{
			name: "InvalidServerIP",
			vars: map[string]interface{}{
				"server_ip": "invalid.ip",
			},
			shouldErr: true,
		},
		{
			name: "InvalidMetalLBRange",
			vars: map[string]interface{}{
				"metallb_ip_range": "10.0.0.200-210",
			},
			shouldErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: "../../terraform",
				NoColor:      true,
				Vars:         tt.vars,
			}

			_, err := terraform.InitE(t, terraformOptions)
			require.NoError(t, err)

			_, err = terraform.ValidateE(t, terraformOptions)
			if tt.shouldErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// Test environment-specific configurations
func TestEnvironmentConfigurations(t *testing.T) {
	t.Parallel()

	environments := []string{"dev", "staging", "prod"}

	for _, env := range environments {
		t.Run(env, func(t *testing.T) {
			varFile := filepath.Join("..", "..", "terraform", "environments", env+".tfvars")

			terraformOptions := &terraform.Options{
				TerraformDir: "../../terraform",
				NoColor:      true,
				VarFiles:     []string{varFile},
			}

			// Just validate that the var files are syntactically correct
			terraform.Init(t, terraformOptions)
			terraform.Validate(t, terraformOptions)
		})
	}
}