# AWS ParallelCluster Infrastructure and Configuration Management
# This Makefile provides convenient targets for common operations

# Virtual environment activation command
VENV_ACTIVATE = source env/bin/activate && export PYTHONWARNINGS=ignore

.PHONY: help init plan apply destroy validate-terraform generate-config validate-config create-cluster delete-cluster ssh-cluster clean status

# Default target
help: ## Show this help message
	@echo "AWS ParallelCluster Infrastructure Management"
	@echo "============================================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration files:"
	@echo "  terraform/terraform.tfvars    - Terraform variables (copy from .example)"
	@echo "  cluster-config-generated.yaml - Generated cluster config"
	@echo ""
	@echo "Example workflow:"
	@echo "  make init plan apply generate-config validate-config create-cluster"

# Terraform operations
init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	cd terraform && terraform init

plan: ## Plan Terraform deployment
	@echo "Planning Terraform deployment..."
	cd terraform && terraform plan

apply: ## Deploy infrastructure with Terraform
	@echo "Deploying infrastructure..."
	cd terraform && terraform apply
	@echo "Infrastructure deployed successfully!"
	@echo "Cluster configuration generated at: cluster-config-generated.yaml"

destroy: ## Destroy infrastructure
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	cd terraform && terraform destroy

validate-terraform: ## Validate Terraform configuration
	@echo "Validating Terraform configuration..."
	cd terraform && terraform validate
	@echo "Terraform configuration is valid!"

# Configuration generation
generate-config: ## Generate cluster configuration from Terraform outputs
	@echo "Generating cluster configuration..."
	cd scripts && ./generate-cluster-config-simple.sh
	@echo "Cluster configuration generated successfully!"

generate-config-full: ## Generate cluster configuration using full-featured script (requires jq)
	@echo "Generating cluster configuration with full script..."
	cd scripts && ./generate-cluster-config.sh
	@echo "Cluster configuration generated successfully!"

# ParallelCluster operations
validate-config: ## Validate the generated cluster configuration
	@echo "Validating cluster configuration..."
	@if [ ! -f "cluster-config-generated.yaml" ]; then \
		echo "ERROR: cluster-config-generated.yaml not found. Run 'make generate-config' first."; \
		exit 1; \
	fi
	$(VENV_ACTIVATE) && pcluster create-cluster --cluster-name test --cluster-configuration cluster-config-generated.yaml --dryrun true
	@echo "Cluster configuration is valid!"

create-cluster: ## Create ParallelCluster (requires NAME variable)
	@if [ -z "$(NAME)" ]; then \
		echo "ERROR: NAME not specified. Usage: make create-cluster NAME=my-cluster"; \
		exit 1; \
	fi
	@if [ ! -f "cluster-config-generated.yaml" ]; then \
		echo "ERROR: cluster-config-generated.yaml not found. Run 'make generate-config' first."; \
		exit 1; \
	fi
	@echo "Creating ParallelCluster: $(NAME)"
	$(VENV_ACTIVATE) && pcluster create-cluster \
		--cluster-name $(NAME) \
		--cluster-configuration cluster-config-generated.yaml
	@echo "Cluster creation started! Monitor progress with: pcluster describe-cluster --cluster-name $(NAME)"

delete-cluster: ## Delete ParallelCluster (requires NAME variable)
	@if [ -z "$(NAME)" ]; then \
		echo "ERROR: NAME not specified. Usage: make delete-cluster NAME=my-cluster"; \
		exit 1; \
	fi
	@echo "WARNING: This will delete the cluster: $(NAME)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	$(VENV_ACTIVATE) && pcluster delete-cluster --cluster-name $(NAME)
	@echo "Cluster deletion started!"

ssh: ## SSH to ParallelCluster head node (requires NAME variable)
	@if [ -z "$(NAME)" ]; then \
		echo "ERROR: NAME not specified. Usage: make ssh-cluster NAME=my-cluster"; \
		exit 1; \
	fi
	@echo "Getting head node information for cluster: $(NAME)"
	@HEAD_NODE_IP=$$($(VENV_ACTIVATE) && pcluster describe-cluster --cluster-name $(NAME) --query 'headNode.publicIpAddress' | tr -d \" 2>/dev/null); \
	if [ "$$HEAD_NODE_IP" = "None" ] || [ -z "$$HEAD_NODE_IP" ]; then \
		echo "ERROR: Could not get head node IP for cluster $(NAME)"; \
		echo "Make sure the cluster exists and is running."; \
		exit 1; \
	fi; \
	echo "Connecting to head node at $$HEAD_NODE_IP"; \
	ssh ec2-user@$$HEAD_NODE_IP

# Status and information
status: ## Show status of infrastructure and clusters
	@echo "=== Terraform Status ==="
	@if [ -f "terraform/terraform.tfstate" ]; then \
		echo "✅ Terraform state found"; \
		cd terraform && terraform output --json > /tmp/tf-output.json 2>/dev/null && echo "✅ Infrastructure deployed" || echo "❌ Infrastructure not deployed"; \
	else \
		echo "❌ Terraform state not found - run 'make apply' first"; \
	fi
	@echo ""
	@echo "=== Configuration Status ==="
	@if [ -f "cluster-config-generated.yaml" ]; then \
		echo "✅ Cluster configuration generated"; \
	else \
		echo "❌ Cluster configuration not generated - run 'make generate-config'"; \
	fi
	@echo ""
	@echo "=== ParallelCluster Status ==="
	@$(VENV_ACTIVATE) && pcluster list-clusters --query 'clusters[].{Name:clusterName,Status:clusterStatus}' 2>/dev/null || echo "No clusters found or pcluster CLI not configured"

outputs: ## Show Terraform outputs
	@echo "Terraform Outputs:"
	@echo "=================="
	cd terraform && terraform output

# # Utility targets
# clean: ## Clean generated files
# 	@echo "Cleaning generated files..."
# 	rm -f cluster-config-generated.yaml
# 	rm -f terraform/.terraform.lock.hcl
# 	rm -rf terraform/.terraform/
# 	@echo "Cleaned successfully!"

setup: ## Setup initial configuration files
	@echo "Setting up initial configuration..."
	@if [ ! -f "terraform/terraform.tfvars" ]; then \
		cp terraform/terraform.tfvars.example terraform/terraform.tfvars; \
		echo "✅ Created terraform/terraform.tfvars from example"; \
		echo "❗ Please edit terraform/terraform.tfvars with your settings"; \
	else \
		echo "✅ terraform/terraform.tfvars already exists"; \
	fi

# Check prerequisites
check-prereqs: ## Check if required tools are installed
	@echo "Checking prerequisites..."
	@which terraform >/dev/null 2>&1 && echo "✅ terraform" || echo "❌ terraform - install from https://terraform.io"
	@which aws >/dev/null 2>&1 && echo "✅ aws CLI" || echo "❌ aws CLI - install from https://aws.amazon.com/cli/"
	@if [ -f "env/bin/activate" ]; then \
		$(VENV_ACTIVATE) && which pcluster >/dev/null 2>&1 && echo "✅ pcluster CLI (in venv)" || echo "❌ pcluster CLI - install with: pip install aws-parallelcluster"; \
	else \
		which pcluster >/dev/null 2>&1 && echo "✅ pcluster CLI (global)" || echo "❌ pcluster CLI - install with: pip install aws-parallelcluster"; \
	fi
	@which jq >/dev/null 2>&1 && echo "✅ jq (optional)" || echo "⚠️  jq (optional) - install for full-featured script support"
	@echo ""
	@echo "Virtual Environment:"
	@if [ -f "env/bin/activate" ]; then \
		echo "✅ Virtual environment found at env/"; \
	else \
		echo "⚠️  Virtual environment not found - create with: python -m venv env && source env/bin/activate && pip install aws-parallelcluster"; \
	fi
	@echo ""
	@echo "AWS Configuration:"
	@aws sts get-caller-identity >/dev/null 2>&1 && echo "✅ AWS credentials configured" || echo "❌ AWS credentials not configured - run 'aws configure'"

# Full deployment workflow
deploy: init plan apply generate-config validate-config ## Complete deployment workflow (init -> plan -> apply -> generate-config -> validate-config)
	@echo ""
	@echo "🎉 Deployment completed successfully!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Review the generated configuration: cluster-config-generated.yaml"
	@echo "2. Create your cluster: make create-cluster NAME=my-cluster"
	@echo "3. Monitor cluster status: pcluster describe-cluster --cluster-name my-cluster"

# # Development targets
# fmt: ## Format Terraform code
# 	cd terraform && terraform fmt -recursive

validate: validate-terraform validate-config ## Validate both Terraform and cluster configurations

# Quick cluster creation for development
dev-cluster: ## Create development cluster with default name
	$(MAKE) create-cluster NAME=dev-pcluster

dev-ssh: ## SSH to development cluster
	$(MAKE) ssh-cluster NAME=dev-pcluster

dev-delete: ## Delete development cluster with default name
	$(MAKE) delete-cluster NAME=dev-pcluster

# Examples in help
examples: ## Show example commands
	@echo "Example Commands:"
	@echo "================"
	@echo ""
	@echo "Complete setup and deployment:"
	@echo "  make setup"
	@echo "  # Edit terraform/terraform.tfvars"
	@echo "  make deploy"
	@echo "  make create-cluster NAME=research-cluster"
	@echo ""
	@echo "Check status:"
	@echo "  make status"
	@echo "  pcluster describe-cluster --cluster-name research-cluster"
	@echo ""
	@echo "Connect to cluster:"
	@echo "  make ssh-cluster NAME=research-cluster"
	@echo "  make ssh-cluster NAME=research-cluster SSH_KEY_PATH=~/.ssh/my-key.pem"
	@echo ""
	@echo "Cleanup:"
	@echo "  make delete-cluster NAME=research-cluster"
	@echo "  make destroy"

# Virtual environment management
venv-create: ## Create virtual environment and install pcluster
	@echo "Creating virtual environment..."
	python -m venv env
	$(VENV_ACTIVATE) && pip install --upgrade pip
	$(VENV_ACTIVATE) && pip install aws-parallelcluster
	@echo "✅ Virtual environment created and pcluster installed!"

venv-update: ## Update pcluster in virtual environment
	@echo "Updating pcluster in virtual environment..."
	$(VENV_ACTIVATE) && pip install --upgrade aws-parallelcluster
	@echo "✅ pcluster updated!"
