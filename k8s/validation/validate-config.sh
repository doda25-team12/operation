#!/bin/bash
# validate-config.sh - Cross-file configuration consistency checker
# Validates Docker Compose and Helm configurations stay synchronized

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERROR_COUNT=0
WARNING_COUNT=0

# Default file paths
VALUES_FILE="$OPERATION_ROOT/k8s/helm-chart/sms-spam-detector/values.yaml"
SCHEMA_FILE="$OPERATION_ROOT/k8s/helm-chart/sms-spam-detector/values.schema.json"
ENV_FILE="$OPERATION_ROOT/.env"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--values-file)
            VALUES_FILE="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --skip-schema)
            SKIP_SCHEMA=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -f, --values-file FILE    Path to values.yaml (default: values.yaml)"
            echo "  --env-file FILE           Path to .env file (default: .env)"
            echo "  --skip-schema             Skip JSON schema validation"
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
echo -e "${BLUE}Configuration Validation Framework${NC}"
echo "=========================================="
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for yq
if ! command_exists yq; then
    echo -e "${RED}❌ Error: yq not installed${NC}"
    echo "   Install: brew install yq (macOS) or see https://github.com/mikefarah/yq"
    exit 1
fi

# Check if files exist
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}❌ Error: values.yaml not found at $VALUES_FILE${NC}"
    exit 1
fi

# ============================================================
# LAYER 1: JSON Schema Validation
# ============================================================
if [ "$SKIP_SCHEMA" != "true" ]; then
    echo -e "${BLUE}[1/6] Validating JSON Schema compliance...${NC}"

    if [ -f "$SCHEMA_FILE" ]; then
        python3 "$SCRIPT_DIR/validate-schema.py" "$VALUES_FILE" "$SCHEMA_FILE"
        if [ $? -ne 0 ]; then
            ((ERROR_COUNT++))
        fi
    else
        echo -e "${YELLOW}⚠ Schema file not found, skipping: $SCHEMA_FILE${NC}"
        ((WARNING_COUNT++))
    fi
    echo ""
else
    echo -e "${YELLOW}[1/6] Skipping JSON schema validation (--skip-schema flag)${NC}"
    echo ""
fi

# ============================================================
# LAYER 2: Port Consistency Validation
# ============================================================
echo -e "${BLUE}[2/6] Checking port consistency...${NC}"

# Extract Helm values using yq
HELM_APP_PORT=$(yq eval '.appService.service.port' "$VALUES_FILE")
HELM_MODEL_PORT=$(yq eval '.modelService.service.port' "$VALUES_FILE")
HELM_CONFIG_APP_PORT=$(yq eval '.config.appInternalPort' "$VALUES_FILE" | tr -d '"')
HELM_CONFIG_MODEL_PORT=$(yq eval '.config.modelInternalPort' "$VALUES_FILE" | tr -d '"')
HELM_MODEL_URL=$(yq eval '.config.modelServiceUrl' "$VALUES_FILE")

# Validate internal Helm consistency
if [ "$HELM_APP_PORT" != "$HELM_CONFIG_APP_PORT" ]; then
    echo -e "${RED}❌ [ERROR] Port mismatch in values.yaml${NC}"
    echo "  appService.service.port:     $HELM_APP_PORT"
    echo "  config.appInternalPort:      $HELM_CONFIG_APP_PORT"
    echo "  Fix: Set both to same value (usually 8080)"
    ((ERROR_COUNT++))
else
    echo -e "${GREEN}✓${NC} App service port aligned: $HELM_APP_PORT"
fi

if [ "$HELM_MODEL_PORT" != "$HELM_CONFIG_MODEL_PORT" ]; then
    echo -e "${RED}❌ [ERROR] Port mismatch in values.yaml${NC}"
    echo "  modelService.service.port:   $HELM_MODEL_PORT"
    echo "  config.modelInternalPort:    $HELM_CONFIG_MODEL_PORT"
    echo "  Fix: Set both to same value (usually 8081)"
    ((ERROR_COUNT++))
else
    echo -e "${GREEN}✓${NC} Model service port aligned: $HELM_MODEL_PORT"
fi

# Validate MODEL_SERVICE_URL construction
EXPECTED_MODEL_URL="http://model-service:${HELM_MODEL_PORT}"
if [ "$HELM_MODEL_URL" != "$EXPECTED_MODEL_URL" ]; then
    echo -e "${YELLOW}⚠ [WARNING] Model service URL may be misconfigured${NC}"
    echo "  Current:  $HELM_MODEL_URL"
    echo "  Expected: $EXPECTED_MODEL_URL"
    echo "  Fix: Update config.modelServiceUrl to match modelService.service.port"
    ((WARNING_COUNT++))
else
    echo -e "${GREEN}✓${NC} Model service URL correct: $HELM_MODEL_URL"
fi

# Cross-validate with .env if it exists
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE" 2>/dev/null || true

    if [ -n "$MODEL_INTERNAL_PORT" ] && [ "$MODEL_INTERNAL_PORT" != "$HELM_MODEL_PORT" ]; then
        echo -e "${RED}❌ [ERROR] Port mismatch between .env and values.yaml${NC}"
        echo "  .env MODEL_INTERNAL_PORT:    $MODEL_INTERNAL_PORT"
        echo "  values.yaml model port:      $HELM_MODEL_PORT"
        echo "  Impact: Docker Compose and Helm configs diverged"
        echo "  Fix: Align both to 8081"
        ((ERROR_COUNT++))
    elif [ -n "$MODEL_INTERNAL_PORT" ]; then
        echo -e "${GREEN}✓${NC} .env and values.yaml model ports aligned"
    fi

    if [ -n "$APP_INTERNAL_PORT" ] && [ "$APP_INTERNAL_PORT" != "$HELM_APP_PORT" ]; then
        echo -e "${RED}❌ [ERROR] Port mismatch between .env and values.yaml${NC}"
        echo "  .env APP_INTERNAL_PORT:      $APP_INTERNAL_PORT"
        echo "  values.yaml app port:        $HELM_APP_PORT"
        echo "  Impact: Docker Compose and Helm configs diverged"
        echo "  Fix: Align both to 8080"
        ((ERROR_COUNT++))
    elif [ -n "$APP_INTERNAL_PORT" ]; then
        echo -e "${GREEN}✓${NC} .env and values.yaml app ports aligned"
    fi
fi

echo ""

# ============================================================
# LAYER 3: Image Tag Coherence Validation
# ============================================================
echo -e "${BLUE}[3/6] Validating image tag coherence...${NC}"

MAIN_IMAGE_TAG=$(yq eval '.modelService.image.tag' "$VALUES_FILE")
CANARY_ENABLED=$(yq eval '.modelService.canary.enabled' "$VALUES_FILE")
CANARY_IMAGE_TAG=$(yq eval '.modelService.canary.image.tag' "$VALUES_FILE")
SHADOW_ENABLED=$(yq eval '.modelService.shadow.enabled' "$VALUES_FILE")
SHADOW_IMAGE_TAG=$(yq eval '.modelService.shadow.image.tag' "$VALUES_FILE")

APP_MAIN_TAG=$(yq eval '.appService.image.tag' "$VALUES_FILE")
APP_CANARY_ENABLED=$(yq eval '.appService.canary.enabled' "$VALUES_FILE")
APP_CANARY_TAG=$(yq eval '.appService.canary.image.tag' "$VALUES_FILE")

# Check model service
if [ "$CANARY_ENABLED" = "true" ] && [ "$MAIN_IMAGE_TAG" = "$CANARY_IMAGE_TAG" ]; then
    echo -e "${RED}❌ [ERROR] Model service canary uses same tag as stable${NC}"
    echo "  Stable tag:  $MAIN_IMAGE_TAG"
    echo "  Canary tag:  $CANARY_IMAGE_TAG"
    echo "  Impact: Canary deployment will not test new version (defeats purpose)"
    echo "  Fix: Use distinct tags (e.g., v1.0.0 vs v1.1.0-rc)"
    ((ERROR_COUNT++))
elif [ "$CANARY_ENABLED" = "true" ]; then
    echo -e "${GREEN}✓${NC} Model service canary uses distinct tag ($CANARY_IMAGE_TAG vs $MAIN_IMAGE_TAG)"
else
    echo -e "${GREEN}✓${NC} Model service canary disabled, no tag conflict"
fi

if [ "$SHADOW_ENABLED" = "true" ] && [ "$MAIN_IMAGE_TAG" = "$SHADOW_IMAGE_TAG" ]; then
    echo -e "${RED}❌ [ERROR] Model service shadow uses same tag as stable${NC}"
    echo "  Stable tag: $MAIN_IMAGE_TAG"
    echo "  Shadow tag: $SHADOW_IMAGE_TAG"
    echo "  Impact: Shadow deployment will not test new version"
    echo "  Fix: Use distinct tag for shadow (e.g., v1.1.0-shadow)"
    ((ERROR_COUNT++))
elif [ "$SHADOW_ENABLED" = "true" ]; then
    echo -e "${GREEN}✓${NC} Model service shadow uses distinct tag ($SHADOW_IMAGE_TAG vs $MAIN_IMAGE_TAG)"
else
    echo -e "${GREEN}✓${NC} Model service shadow disabled, no tag conflict"
fi

# Check app service
if [ "$APP_CANARY_ENABLED" = "true" ] && [ "$APP_MAIN_TAG" = "$APP_CANARY_TAG" ]; then
    echo -e "${RED}❌ [ERROR] App service canary uses same tag as stable${NC}"
    echo "  Stable tag: $APP_MAIN_TAG"
    echo "  Canary tag: $APP_CANARY_TAG"
    echo "  Impact: Canary will run same code as stable"
    echo "  Fix: Use distinct tags"
    ((ERROR_COUNT++))
elif [ "$APP_CANARY_ENABLED" = "true" ]; then
    echo -e "${GREEN}✓${NC} App service canary uses distinct tag ($APP_CANARY_TAG vs $APP_MAIN_TAG)"
else
    echo -e "${GREEN}✓${NC} App service canary disabled, no tag conflict"
fi

echo ""

# ============================================================
# LAYER 4: Version Label Alignment
# ============================================================
echo -e "${BLUE}[4/6] Checking version label alignment...${NC}"

MAIN_VERSION_LABEL=$(yq eval '.modelService.versionLabel' "$VALUES_FILE")
CANARY_VERSION_LABEL=$(yq eval '.modelService.canary.versionLabel' "$VALUES_FILE")

# Validate that versionLabel differs from canary versionLabel
if [ "$CANARY_ENABLED" = "true" ] && [ "$MAIN_VERSION_LABEL" = "$CANARY_VERSION_LABEL" ]; then
    echo -e "${RED}❌ [ERROR] Version labels must differ for canary deployment${NC}"
    echo "  Stable: $MAIN_VERSION_LABEL"
    echo "  Canary: $CANARY_VERSION_LABEL"
    echo "  Impact: Istio routing will not distinguish versions"
    echo "  Fix: Use v1 vs v2, or v1 vs v1-canary"
    ((ERROR_COUNT++))
elif [ "$CANARY_ENABLED" = "true" ]; then
    echo -e "${GREEN}✓${NC} Version labels distinct ($MAIN_VERSION_LABEL vs $CANARY_VERSION_LABEL)"
else
    echo -e "${GREEN}✓${NC} Canary disabled, version labels not validated"
fi

echo ""

# ============================================================
# LAYER 5: ConfigMap Completeness
# ============================================================
echo -e "${BLUE}[5/6] Validating ConfigMap completeness...${NC}"

CONFIGMAP_FILE="$OPERATION_ROOT/k8s/helm-chart/sms-spam-detector/templates/configmap.yaml"
if [ -f "$CONFIGMAP_FILE" ]; then
    if grep -q "MODEL_VERSION" "$CONFIGMAP_FILE"; then
        echo -e "${GREEN}✓${NC} MODEL_VERSION present in ConfigMap template"
    else
        echo -e "${YELLOW}⚠ [WARNING] MODEL_VERSION missing from ConfigMap${NC}"
        echo "  File: templates/configmap.yaml"
        echo "  Impact: model-service will crash with RuntimeError"
        echo "  Suggested fix: Add to configmap.yaml:"
        echo '    MODEL_VERSION: {{ .Values.modelService.image.tag | replace "v" "" | quote }}'
        ((WARNING_COUNT++))
    fi
else
    echo -e "${YELLOW}⚠ [WARNING] ConfigMap template not found: $CONFIGMAP_FILE${NC}"
    ((WARNING_COUNT++))
fi

echo ""

# ============================================================
# LAYER 6: Environment Variable Completeness
# ============================================================
echo -e "${BLUE}[6/6] Validating environment variable completeness...${NC}"

# Check if all .env variables are used in docker-compose.yml
DOCKER_COMPOSE="$OPERATION_ROOT/docker-compose.yml"
if [ -f "$DOCKER_COMPOSE" ] && [ -f "$ENV_FILE" ]; then
    for var in ORG_NAME VERSION HOST_PORT APP_INTERNAL_PORT MODEL_INTERNAL_PORT; do
        if ! grep -q "\${$var}" "$DOCKER_COMPOSE"; then
            echo -e "${YELLOW}⚠ [WARNING] .env variable $var not used in docker-compose.yml${NC}"
            ((WARNING_COUNT++))
        else
            echo -e "${GREEN}✓${NC} .env variable $var used in docker-compose.yml"
        fi
    done
else
    echo -e "${YELLOW}⚠ [WARNING] docker-compose.yml or .env not found, skipping cross-validation${NC}"
fi

echo ""

# ============================================================
# Summary
# ============================================================
echo "=========================================="
echo -e "${BLUE}Validation Summary${NC}"
echo "=========================================="
echo -e "Errors:   ${RED}$ERROR_COUNT${NC}"
echo -e "Warnings: ${YELLOW}$WARNING_COUNT${NC}"
echo ""

if [ $ERROR_COUNT -eq 0 ] && [ $WARNING_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ All validations passed!${NC}"
    echo ""
    exit 0
elif [ $ERROR_COUNT -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation passed with warnings${NC}"
    echo "   Review warnings above and fix if needed"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERROR_COUNT error(s)${NC}"
    echo "   Fix errors above before deploying"
    echo ""
    exit 1
fi
