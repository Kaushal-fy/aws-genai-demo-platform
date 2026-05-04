#!/usr/bin/env bash
# =============================================================================
# setup_mode_a_amazon_linux.sh
#
# Purpose:
#   Install and configure every prerequisite needed to run Mode A of the
#   aws-genai-demo-platform Terraform stack on a fresh Amazon Linux 2 or
#   Amazon Linux 2023 (AL2023) instance.
#
# Mode A definition (from terraform/full_product/README.md):
#   A single `terraform apply` that builds the Docker worker image locally,
#   pushes it to ECR, and deploys the full AWS stack.  The machine running
#   Terraform must have:
#     - Docker daemon (to build + push the worker image)
#     - AWS CLI v2    (used by the Terraform ECR null_resource provisioner)
#     - Terraform ≥ 1.6
#
# What this script does:
#   1. Detect Amazon Linux version (2 or 2023)
#   2. Update system packages
#   3. Install utilities  : git, unzip, jq, curl, wget
#   4. Install Docker     : start daemon, enable on boot, add $USER to docker group
#   5. Install AWS CLI v2 : download official installer from AWS, verify, install
#   6. Install Terraform  : add HashiCorp yum repo, install terraform ≥ 1.6
#   7. Verify all tools are available and print their versions
#   8. Print next-step instructions specific to Mode A
#
# Usage:
#   chmod +x scripts/setup_mode_a_amazon_linux.sh
#   ./scripts/setup_mode_a_amazon_linux.sh
#
#   Run as a non-root user that has sudo privileges (e.g. ec2-user).
#   The script will call sudo internally where root is needed.
#
# After the script finishes:
#   Log out and log back in (or run `newgrp docker`) so the docker group
#   membership takes effect for the current shell.
# =============================================================================

set -euo pipefail

# ── Colours for readable output ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'   # no colour

step()  { echo -e "\n${CYAN}[STEP]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Minimum Terraform version required by the stack ───────────────────────────
TF_MIN_VERSION="1.6.0"

# =============================================================================
# 1. Detect OS version
# =============================================================================
step "Detecting Amazon Linux version …"

if [[ ! -f /etc/os-release ]]; then
  die "Cannot find /etc/os-release – is this an Amazon Linux instance?"
fi

source /etc/os-release

case "$VERSION_ID" in
  2)    AL_VERSION=2;    PKG_MGR="yum";  ok "Amazon Linux 2 detected" ;;
  2023) AL_VERSION=2023; PKG_MGR="dnf";  ok "Amazon Linux 2023 detected" ;;
  *)    die "Unsupported Amazon Linux version: $VERSION_ID. This script supports AL2 and AL2023." ;;
esac

# =============================================================================
# 2. Update system packages
# =============================================================================
step "Updating system packages …"
sudo $PKG_MGR update -y
ok "System packages updated"

# =============================================================================
# 3. Install utilities
# =============================================================================
step "Installing utilities (git, unzip, jq, curl, wget) …"

if [[ $AL_VERSION -eq 2023 ]]; then
  # AL2023 ships with curl-minimal which provides the curl binary but conflicts
  # with the full curl package.  Install everything else and leave curl-minimal
  # in place.  The curl binary is already functional for our purposes.
  sudo $PKG_MGR install -y git unzip jq wget
  ok "Utilities installed (curl already provided by curl-minimal on AL2023)"
else
  sudo $PKG_MGR install -y git unzip jq curl wget
  ok "Utilities installed"
fi

# =============================================================================
# 4. Install Docker and start the daemon
# =============================================================================
step "Installing Docker …"

if command -v docker &>/dev/null; then
  ok "Docker already installed: $(docker --version)"
else
  if [[ $AL_VERSION -eq 2 ]]; then
    # AL2: docker is in amazon-linux-extras
    sudo amazon-linux-extras install -y docker
  else
    # AL2023: docker is in the standard repo
    sudo dnf install -y docker
  fi
  ok "Docker installed"
fi

step "Starting and enabling Docker daemon …"
sudo systemctl start docker
sudo systemctl enable docker
ok "Docker daemon running"

step "Adding $USER to the 'docker' group …"
if id -nG "$USER" | grep -qw docker; then
  ok "$USER is already in the docker group"
else
  sudo usermod -aG docker "$USER"
  warn "Added $USER to docker group – you must log out and back in (or run 'newgrp docker') for this to take effect in the current shell"
fi

# =============================================================================
# 5. Install AWS CLI v2
# =============================================================================
step "Installing AWS CLI v2 …"

if aws --version 2>/dev/null | grep -q "aws-cli/2"; then
  ok "AWS CLI v2 already installed: $(aws --version)"
else
  ARCH=$(uname -m)
  if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
  else
    AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  fi

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  step "  Downloading AWS CLI installer from ${AWS_CLI_URL} …"
  curl -fsSL "$AWS_CLI_URL" -o "$TMP_DIR/awscliv2.zip"

  step "  Extracting and installing AWS CLI …"
  unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"
  sudo "$TMP_DIR/aws/install" --update

  ok "AWS CLI v2 installed: $(aws --version)"
fi

# =============================================================================
# 6. Install Terraform
#
# Strategy:
#   AL2    → HashiCorp yum repo (AmazonLinux/2) + yum install terraform
#   AL2023 → Direct binary download from releases.hashicorp.com
#            HashiCorp does NOT publish a yum repo for AL2023 (all known
#            paths return HTTP 404), so the binary method is the only
#            reliable option.
# =============================================================================

_install_terraform_via_binary() {
  local arch
  arch=$(uname -m)
  local tf_arch
  case "$arch" in
    x86_64)          tf_arch="amd64" ;;
    aarch64|arm64)   tf_arch="arm64" ;;
    *)               die "Unsupported architecture for Terraform binary download: $arch" ;;
  esac

  step "Fetching latest Terraform version from HashiCorp checkpoint API …"
  local tf_version
  tf_version=$(curl -fsSL "https://checkpoint-api.hashicorp.com/v1/check/terraform" \
               | jq -r '.current_version')
  [[ -z "$tf_version" ]] && die "Could not determine latest Terraform version from checkpoint API."

  # Ensure the fetched version satisfies the minimum
  local lowest
  lowest=$(printf '%s\n%s' "$TF_MIN_VERSION" "$tf_version" | sort -V | head -1)
  if [[ "$lowest" != "$TF_MIN_VERSION" ]]; then
    die "Latest Terraform version $tf_version is below required $TF_MIN_VERSION – this is unexpected. Check the checkpoint API."
  fi

  local tf_zip="terraform_${tf_version}_linux_${tf_arch}.zip"
  local tf_url="https://releases.hashicorp.com/terraform/${tf_version}/${tf_zip}"

  step "Downloading Terraform ${tf_version} (${tf_arch}) …"
  local tmp
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  curl -fsSL "$tf_url" -o "$tmp/$tf_zip"
  unzip -q "$tmp/$tf_zip" -d "$tmp"
  sudo install -o root -g root -m 0755 "$tmp/terraform" /usr/local/bin/terraform
  rm -rf "$tmp"

  ok "Terraform $(terraform version | head -1) installed to /usr/local/bin/terraform"
}

_install_terraform_via_repo() {
  step "Configuring HashiCorp yum repository for Terraform (AL2) …"
  sudo $PKG_MGR install -y yum-utils
  sudo yum-config-manager --add-repo \
    "https://rpm.releases.hashicorp.com/AmazonLinux/2/hashicorp.repo"
  ok "HashiCorp repo configured"

  sudo $PKG_MGR install -y terraform
  ok "Terraform installed: $(terraform version | head -1)"
}

step "Installing Terraform …"

if command -v terraform &>/dev/null; then
  INSTALLED_TF=$(terraform version -json 2>/dev/null \
    | jq -r '.terraform_version' 2>/dev/null \
    || terraform version | head -1 | grep -oP '\d+\.\d+\.\d+')
  LOWEST=$(printf '%s\n%s' "$TF_MIN_VERSION" "$INSTALLED_TF" | sort -V | head -1)
  if [[ "$LOWEST" == "$TF_MIN_VERSION" ]]; then
    ok "Terraform $INSTALLED_TF already satisfies ≥ $TF_MIN_VERSION – skipping install"
  else
    warn "Installed Terraform $INSTALLED_TF < required $TF_MIN_VERSION – upgrading …"
    if [[ $AL_VERSION -eq 2 ]]; then
      _install_terraform_via_repo
    else
      _install_terraform_via_binary
    fi
  fi
else
  if [[ $AL_VERSION -eq 2 ]]; then
    _install_terraform_via_repo
  else
    _install_terraform_via_binary
  fi
fi

# =============================================================================
# 7. Verify all required tools
# =============================================================================
step "Verifying installed tools …"

MISSING=()

for tool in docker aws terraform git; do
  if command -v "$tool" &>/dev/null; then
    VERSION_OUT=$("$tool" version 2>/dev/null || "$tool" --version 2>/dev/null || echo "version not available")
    ok "$tool → $(echo "$VERSION_OUT" | head -1)"
  else
    warn "$tool NOT found in PATH"
    MISSING+=("$tool")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  die "The following tools are still missing: ${MISSING[*]}. Review the errors above."
fi

# Verify Docker daemon is actually reachable (important for Mode A)
step "Verifying Docker daemon is reachable …"
if sudo docker info &>/dev/null; then
  ok "Docker daemon is reachable"
else
  die "Docker daemon is not reachable. Check 'sudo systemctl status docker'."
fi

# =============================================================================
# 8. Next-step instructions for Mode A
# =============================================================================
echo ""
echo -e "${GREEN}=================================================================${NC}"
echo -e "${GREEN} All Mode A prerequisites are installed successfully!${NC}"
echo -e "${GREEN}=================================================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} Log out and log back in (or run ${CYAN}newgrp docker${NC}) so"
echo "the docker group membership takes effect for your current shell."
echo ""
echo -e "${CYAN}Next steps to deploy Mode A:${NC}"
echo ""
echo "  1. Ensure your AWS credentials are configured:"
echo "       aws configure"
echo "     Or export environment variables:"
echo "       export AWS_ACCESS_KEY_ID=<key>"
echo "       export AWS_SECRET_ACCESS_KEY=<secret>"
echo "       export AWS_DEFAULT_REGION=us-east-1"
echo ""
echo "  2. Clone the repository (if not already present):"
echo "       git clone https://github.com/Kaushal-fy/aws-genai-demo-platform.git"
echo "       cd aws-genai-demo-platform"
echo ""
echo "  3. Prepare Terraform variables:"
echo "       cd terraform/full_product"
echo "       cp terraform.tfvars.example terraform.tfvars"
echo "       # Edit terraform.tfvars – set aws_region, project_name,"
echo "       # environment, bedrock_model_id.  Leave build_worker_image=true."
echo ""
echo "  4. Deploy (Mode A – Docker builds and pushes the worker image):"
echo "       terraform init"
echo "       terraform apply"
echo ""
echo "  5. After apply, collect outputs:"
echo "       terraform output api_base_url"
echo "       terraform output artifact_bucket_name"
echo ""
echo "  6. Test the API:"
echo "       API_BASE_URL=\$(terraform output -raw api_base_url)"
echo "       curl -X POST \"\$API_BASE_URL/generate-demo-async\" \\"
echo "         -H 'Content-Type: application/json' \\"
echo "         -d '{\"use_case\":\"payment\",\"complexity\":\"high\"}'"
echo ""
echo "See terraform/full_product/README.md for full documentation."
echo ""
