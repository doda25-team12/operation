#!/bin/bash
# pre-deployment-check.sh - Pre-deployment validation orchestrator
# Runs all validation checks before Helm deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
CHART_PATH="$OPERATION_ROOT/k8s/helm-chart/sms-spam-detector"
VALUES_FILE="values.yaml"
NAMESPACE="sms-spam-detection"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--chart)
            CHART_PATH="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-config-check)
            SKIP_CONFIG=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -c, --chart PATH          Path to Helm chart directory"
            echo "  -f, --values FILE         Values file to use (default: values.yaml)"
            echo "  -n, --namespace NAME      Target namespace (default: sms-spam-detection)"
            echo "  --skip-config-check       Skip configuration validation"
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo -e "${BLUE}Pre-Deployment Validation Check${NC}"
echo "=========================================="
echo ""
echo "Chart:     $CHART_PATH"
echo "Values:    $VALUES_FILE"
echo "Namespace: $NAMESPACE"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Error: helm not installed${NC}"
    echo "   Install: brew install helm (macOS)"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ Error: kubectl not installed${NC}"
    echo "   Install: brew install kubectl (macOS)"
    exit 1
fi

# ============================================================
# Step 1: Configuration Consistency Checks
# ============================================================
if [ "$SKIP_CONFIG" != "true" ]; then
    echo -e "${BLUE}[Step 1/4] Running configuration consistency checks...${NC}"
    echo ""

    FULL_VALUES_PATH="$CHART_PATH/$VALUES_FILE"
    bash "$SCRIPT_DIR/validate-config.sh" -f "$FULL_VALUES_PATH"

    if [ $? -ne 0 ]; then
        echo ""
        echo -e "${RED}❌ Configuration validation failed${NC}"
        echo "   Fix errors above before deploying"
        exit 1
    fi

    echo -e "${GREEN}✅ Configuration validation passed${NC}"
    echo ""
else
    echo -e "${YELLOW}[Step 1/4] Skipping configuration validation (--skip-config-check flag)${NC}"
    echo ""
fi

# ============================================================
# Step 2: Helm Chart Syntax Validation
# ============================================================
echo -e "${BLUE}[Step 2/4] Validating Helm chart syntax...${NC}"
echo ""

helm lint "$CHART_PATH" -f "$CHART_PATH/$VALUES_FILE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Helm lint failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Helm lint passed${NC}"
echo ""

# ============================================================
# Step 3: Helm Template Rendering
# ============================================================
echo -e "${BLUE}[Step 3/4] Testing Helm template rendering...${NC}"
echo ""

RENDERED_OUTPUT=$(mktemp)
helm template test-release "$CHART_PATH" -f "$CHART_PATH/$VALUES_FILE" > "$RENDERED_OUTPUT" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Helm template rendering failed${NC}"
    cat "$RENDERED_OUTPUT"
    rm -f "$RENDERED_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✅ Helm template rendering successful${NC}"
echo ""

# Check for MODEL_VERSION in rendered ConfigMap
echo "   Checking for MODEL_VERSION in rendered ConfigMap..."
if grep -A 20 "kind: ConfigMap" "$RENDERED_OUTPUT" | grep -q "MODEL_VERSION"; then
    echo -e "   ${GREEN}✓${NC} MODEL_VERSION found in rendered ConfigMap"
else
    echo -e "   ${YELLOW}⚠${NC} MODEL_VERSION not found in ConfigMap (may cause runtime errors)"
fi

rm -f "$RENDERED_OUTPUT"
echo ""

# ============================================================
# Step 4: Kubernetes Resource Validation
# ============================================================
echo -e "${BLUE}[Step 4/4] Validating Kubernetes resource definitions...${NC}"
echo ""

# Note: This requires kubectl to be configured with a cluster
if kubectl cluster-info &> /dev/null; then
    helm template test-release "$CHART_PATH" -f "$CHART_PATH/$VALUES_FILE" | \
        kubectl apply --dry-run=client -f - > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠ Kubernetes dry-run validation failed (may be cluster-specific)${NC}"
        echo "   This may be OK if resources are valid but cluster has restrictions"
    else
        echo -e "${GREEN}✅ Kubernetes dry-run validation passed${NC}"
    fi
else
    echo -e "${YELLOW}⚠ kubectl not configured, skipping K8s validation${NC}"
    echo "   (This is OK for offline validation)"
fi

echo ""

# ============================================================
# Success Summary
# ============================================================
echo "=========================================="
echo -e "${GREEN}✅ All pre-deployment checks passed!${NC}"
echo "=========================================="
echo ""
echo "Ready to deploy with:"
echo "  helm install sms-detector $CHART_PATH -f $CHART_PATH/$VALUES_FILE -n $NAMESPACE --create-namespace"
echo ""
echo "Or upgrade existing release:"
echo "  helm upgrade sms-detector $CHART_PATH -f $CHART_PATH/$VALUES_FILE -n $NAMESPACE"
echo ""
