# Makefile for Matrix Synapse Helm Chart

CHART_DIR := chart
HELM := helm
KUBECTL := kubectl

.PHONY: help lint template validate test package clean

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

lint: ## Lint the Helm chart
	@echo "Linting Helm chart..."
	$(HELM) lint $(CHART_DIR)
	@echo "✅ Lint completed successfully"

template: ## Render Helm templates
	@echo "Rendering Helm templates..."
	$(HELM) template test-release $(CHART_DIR) --output-dir /tmp/rendered-templates
	@echo "✅ Templates rendered to /tmp/rendered-templates"

validate: lint template ## Run validation checks
	@echo "Running validation checks..."
	@# Check for hardcoded secrets
	@if grep -r "uLJ62kwNWO_DLcKAmbzqYkFwlDQWjNl5" $(CHART_DIR)/templates/; then \
		echo "❌ Found hardcoded macaroon_secret_key"; exit 1; \
	fi
	@if grep -r "2iTjom-bIq5Yh6:afKjUed" $(CHART_DIR)/templates/; then \
		echo "❌ Found hardcoded form_secret"; exit 1; \
	fi
	@if grep -r '"ChangeMe"' $(CHART_DIR)/templates/; then \
		echo "❌ Found hardcoded 'ChangeMe' secret"; exit 1; \
	fi
	@# Check for generated secrets
	@if ! grep -q "macaroonSecretKey" /tmp/rendered-templates/synapse-tenant/templates/matrix-secret.yaml; then \
		echo "❌ macaroonSecretKey not found in rendered templates"; exit 1; \
	fi
	@if ! grep -q "formSecret" /tmp/rendered-templates/synapse-tenant/templates/matrix-secret.yaml; then \
		echo "❌ formSecret not found in rendered templates"; exit 1; \
	fi
	@echo "✅ All validation checks passed"

test: validate ## Run comprehensive tests
	@echo "Running comprehensive tests..."
	@# Test secret uniqueness
	$(HELM) template test1 $(CHART_DIR) > /tmp/test1.yaml
	$(HELM) template test2 $(CHART_DIR) > /tmp/test2.yaml
	@secret1=$$(grep -A 10 "kind: Secret" /tmp/test1.yaml | grep "macaroonSecretKey:" | cut -d: -f2 | tr -d ' '); \
	secret2=$$(grep -A 10 "kind: Secret" /tmp/test2.yaml | grep "macaroonSecretKey:" | cut -d: -f2 | tr -d ' '); \
	if [ "$$secret1" = "$$secret2" ]; then \
		echo "❌ Secrets are not being auto-generated properly"; exit 1; \
	else \
		echo "✅ Secrets are auto-generated and unique"; \
	fi
	@echo "✅ All tests passed"

package: validate ## Package the Helm chart
	@echo "Packaging Helm chart..."
	mkdir -p dist
	$(HELM) package $(CHART_DIR) --destination dist/
	@echo "✅ Chart packaged successfully"

clean: ## Clean up temporary files
	@echo "Cleaning up temporary files..."
	rm -rf /tmp/rendered-templates /tmp/test1.yaml /tmp/test2.yaml dist/
	@echo "✅ Cleanup completed"

install: ## Install the chart in the current Kubernetes context
	@echo "Installing chart..."
	$(HELM) install matrix-synapse $(CHART_DIR)

uninstall: ## Uninstall the chart from the current Kubernetes context
	@echo "Uninstalling chart..."
	$(HELM) uninstall matrix-synapse

upgrade: ## Upgrade the chart in the current Kubernetes context
	@echo "Upgrading chart..."
	$(HELM) upgrade matrix-synapse $(CHART_DIR)

# Convenience target for full validation pipeline
ci: clean validate test package ## Run the full CI validation pipeline
	@echo "✅ CI pipeline completed successfully"