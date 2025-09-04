# AWS ParallelCluster Infrastructure and Configuration Management
# This Makefile provides convenient targets for common operations

# Virtual environment activation command
VENV_ACTIVATE = source env/bin/activate && export PYTHONWARNINGS=ignore

.PHONY: help init plan apply destroy validate-terraform generate-config validate-config create-cluster delete-cluster ssh-cluster clean status image-list image-build image-status image-delete

# Default target
help: ## Show this help message
	@echo "AWS ParallelCluster Infrastructure Management"
	@echo "============================================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration files:"
	@echo "  terraform/terraform.tfvars       - Terraform variables (copy from .example)"
	@echo "  cluster-config-generated.yaml    - Generated cluster config"
	@echo "  imagebuilder-config-generated.yaml - Generated imagebuilder config"
	@echo ""
	@echo "Image Builder operations:"
	@echo "  make image-list                  - List all custom images"
	@echo "  make image-build ID=name         - Build a custom image"
	@echo "  make image-status ID=name        - Check image build status"
	@echo "  make image-delete ID=name        - Delete a custom image"
	@echo ""

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
generate-config: ## Generate cluster and imagebuilder configurations from Terraform templates
	@echo "Generating cluster and imagebuilder configurations..."
	cd terraform && terraform apply -auto-approve -target=local_file.cluster_config -target=local_file.imagebuilder_config
	@echo "Cluster and imagebuilder configurations generated successfully!"

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
	@if [ -f "imagebuilder-config-generated.yaml" ]; then \
		echo "✅ Image Builder configuration generated"; \
	else \
		echo "❌ Image Builder configuration not generated - run 'make generate-config'"; \
	fi
	@echo ""
	@echo "=== ParallelCluster Status ==="
	@echo "CLUSTER_NAME STATUS REGION VERSION SCHEDULER" | column -t
	@$(VENV_ACTIVATE) && pcluster list-clusters --query "clusters" 2>/dev/null | jq -r '.[] | [.clusterName, .clusterStatus, .region, .version, .scheduler.type] | @tsv' | column -t || echo "No clusters found or pcluster CLI not configured"
	@echo ""
	@echo "=== Custom Images Status ==="
	@echo "IMAGE_ID IMAGEBUILDSTATUS AMI_ID REGION" | column -t
	@echo "--- AVAILABLE IMAGES ---"
	@$(VENV_ACTIVATE) && pcluster list-images --image-status AVAILABLE --query "sort_by(images, &imageId)" | jq -r '.[] | [.imageId, .imageBuildStatus, .ec2AmiInfo.amiId, .region] | @tsv' | column -t

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
deploy: init apply validate-config ## Complete deployment workflow (init -> apply -> validate-config)
	@echo ""
	@echo "🎉 Deployment completed successfully!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Review the generated configurations:"
	@echo "   - cluster-config-generated.yaml (for cluster creation)"
	@echo "   - imagebuilder-config-generated.yaml (for custom image building)"
	@echo "2. Create your cluster: make create-cluster CLUSTER_NAME=my-cluster"
	@echo "3. Monitor cluster status: pcluster describe-cluster --cluster-name my-cluster"

# # Development targets
# fmt: ## Format Terraform code
# 	cd terraform && terraform fmt -recursive

validate: validate-terraform validate-config ## Validate both Terraform and cluster configurations

# Quick cluster creation for development
dev-cluster: ## Create development cluster with default name
	$(MAKE) create-cluster NAME=dev-pcluster

dev-ssh: ## SSH to development cluster
	$(MAKE) ssh NAME=dev-pcluster

dev-delete: ## Delete development cluster with default name
	$(MAKE) delete-cluster NAME=dev-pcluster

# Image Builder Operations
image-list: ## List all ParallelCluster custom images, ordered by imageId
	@echo "Listing all custom images..."
	@echo "IMAGE_ID IMAGEBUILDSTATUS AMI_ID REGION" | column -t
	@echo "--- AVAILABLE IMAGES ---"
	@$(VENV_ACTIVATE) && pcluster list-images --image-status AVAILABLE --query "sort_by(images, &imageId)" | jq -r '.[] | [.imageId, .imageBuildStatus, .ec2AmiInfo.amiId, .region] | @tsv' | column -t
	@echo "--- PENDING IMAGES ---"
	@$(VENV_ACTIVATE) && pcluster list-images --image-status PENDING --query "sort_by(images, &imageId)" | jq -r '.[] | [.imageId, .imageBuildStatus, .ec2AmiInfo.amiId, .region] | @tsv' | column -t
	@echo "--- FAILED IMAGES ---"
	@$(VENV_ACTIVATE) && pcluster list-images --image-status FAILED --query "sort_by(images, &imageId)" | jq -r '.[] | [.imageId, .imageBuildStatus, .ec2AmiInfo.amiId, .region] | @tsv' | column -t

image-build: ## Build a custom ParallelCluster image (optional: ID=custom-name, CONFIG=path, WAIT=true)
	@echo "Building custom image..."
	@if [ -z "$(ID)" ]; then \
		IMAGE_ID=$$(date +pcluster-custom-%Y%m%d-%H%M%S); \
		echo "Generated image ID: $$IMAGE_ID"; \
	else \
		IMAGE_ID="$(ID)"; \
		echo "Using provided image ID: $$IMAGE_ID"; \
	fi; \
	CONFIG_FILE="$${CONFIG:-imagebuilder-config-generated.yaml}"; \
	if [ ! -f "$$CONFIG_FILE" ]; then \
		echo "Config file not found: $$CONFIG_FILE"; \
		exit 1; \
	fi; \
	echo "Using config file: $$CONFIG_FILE"; \
	$(VENV_ACTIVATE) && pcluster build-image --image-configuration "$$CONFIG_FILE" --image-id "$$IMAGE_ID"; \
	if [ "$${WAIT:-false}" = "true" ]; then \
		echo "Waiting for build completion..."; \
		TIMEOUT=3600; \
		ELAPSED=0; \
		SLEEP_TIME=30; \
		while [ $$ELAPSED -lt $$TIMEOUT ]; do \
			STATUS=$$($(VENV_ACTIVATE) && pcluster describe-image --image-id "$$IMAGE_ID" --query 'imageBuildStatus' | tr -d '"'); \
			echo "Current status: $$STATUS ($$ELAPSED seconds elapsed)"; \
			if [ "$$STATUS" = "BUILD_COMPLETE" ]; then \
				AMI_ID=$$($(VENV_ACTIVATE) && pcluster describe-image --image-id "$$IMAGE_ID" --query 'ec2AmiInfo.amiId' | tr -d '"'); \
				echo "AMI ID: $$AMI_ID"; \
				break; \
			elif [ "$$STATUS" = "BUILD_FAILED" ]; then \
				break; \
			elif [ "$$STATUS" != "BUILD_IN_PROGRESS" ]; then \
				break; \
			fi; \
			sleep $$SLEEP_TIME; \
			ELAPSED=$$((ELAPSED + SLEEP_TIME)); \
		done; \
		if [ $$ELAPSED -ge $$TIMEOUT ]; then \
			echo "Build timeout reached ($$TIMEOUT seconds)"; \
		fi; \
	else \
		echo "Build is running in the background"; \
		echo "Check status with: make image-status ID=$$IMAGE_ID"; \
	fi

image-status: ## Check status of an image build (requires ID)
	@if [ -z "$(ID)" ]; then \
		echo "Image ID not specified. Usage: make image-status ID=my-image-id"; \
		exit 1; \
	fi; \
	echo "Checking status for image: $(ID)"; \
	$(VENV_ACTIVATE) && pcluster describe-image --image-id "$(ID)"

image-delete: ## Delete a custom image (requires ID)
	@if [ -z "$(ID)" ]; then \
		echo "Image ID not specified. Usage: make image-delete ID=my-image-id"; \
		exit 1; \
	fi; \
	echo "Deleting image: $(ID)"; \
	read -p "Are you sure you want to delete this image? (y/N): " confirm && [ "$$confirm" = "y" ]; \
	$(VENV_ACTIVATE) && pcluster delete-image --image-id "$(ID)"

# Examples in help
examples: ## Show example commands
	@echo "Example Commands:"
	@echo "================"
	@echo ""
	@echo "Complete setup and deployment:"
	@echo "  make setup"
	@echo "  # Edit terraform/terraform.tfvars (optionally set custom_ami)"
	@echo "  make deploy"
	@echo "  make create-cluster CLUSTER_NAME=research-cluster"
	@echo ""
	@echo "Check status:"
	@echo "  make status"
	@echo "  pcluster describe-cluster --cluster-name research-cluster"
	@echo ""
	@echo "Connect to cluster:"
	@echo "  make ssh-cluster NAME=research-cluster"
	@echo "  make ssh-cluster NAME=research-cluster SSH_KEY_PATH=~/.ssh/my-key.pem"
	@echo ""
	@echo "Custom Image operations:"
	@echo "  make image-list"
	@echo "  make image-build ID=my-custom-image CONFIG=imagebuilder-config-generated.yaml WAIT=true"
	@echo "  make image-status ID=my-custom-image"
	@echo "  make image-delete ID=my-custom-image"
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
