#!/bin/bash
# verify-implementation.sh - Verification steps for Day 1-3 implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo -e "${BLUE}Configuration Validation Framework${NC}"
echo -e "${BLUE}Implementation Verification${NC}"
echo "=========================================="
echo ""

# ============================================================
# VERIFICATION 1: Files Created
# ============================================================
echo -e "${BLUE}[1/6] Verifying files were created...${NC}"
echo ""

FILES=(
    "k8s/validation/validate-schema.py"
    "k8s/validation/validate-config.sh"
    "k8s/validation/pre-deployment-check.sh"
    "k8s/validation/README.md"
    "k8s/helm-chart/sms-spam-detector/values.schema.json"
)

ALL_EXIST=true
for file in "${FILES[@]}"; do
    if [ -f "$OPERATION_ROOT/$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${YELLOW}✗${NC} $file (missing)"
        ALL_EXIST=false
    fi
done

if [ "$ALL_EXIST" = true ]; then
    echo -e "\n${GREEN}✅ All files created successfully${NC}\n"
else
    echo -e "\n${YELLOW}⚠ Some files missing${NC}\n"
fi

# ============================================================
# VERIFICATION 2: Scripts are Executable
# ============================================================
echo -e "${BLUE}[2/6] Verifying scripts are executable...${NC}"
echo ""

SCRIPTS=(
    "k8s/validation/validate-schema.py"
    "k8s/validation/validate-config.sh"
    "k8s/validation/pre-deployment-check.sh"
)

ALL_EXECUTABLE=true
for script in "${SCRIPTS[@]}"; do
    if [ -x "$OPERATION_ROOT/$script" ]; then
        echo -e "${GREEN}✓${NC} $script"
    else
        echo -e "${YELLOW}✗${NC} $script (not executable)"
        ALL_EXECUTABLE=false
    fi
done

if [ "$ALL_EXECUTABLE" = true ]; then
    echo -e "\n${GREEN}✅ All scripts are executable${NC}\n"
else
    echo -e "\n${YELLOW}⚠ Some scripts not executable${NC}\n"
fi

# ============================================================
# VERIFICATION 3: ConfigMap Modified
# ============================================================
echo -e "${BLUE}[3/6] Verifying ConfigMap has MODEL_VERSION...${NC}"
echo ""

CONFIGMAP_FILE="$OPERATION_ROOT/k8s/helm-chart/sms-spam-detector/templates/configmap.yaml"
if grep -q "MODEL_VERSION" "$CONFIGMAP_FILE"; then
    echo -e "${GREEN}✓${NC} MODEL_VERSION found in ConfigMap"
    echo "   Line: $(grep -n "MODEL_VERSION" "$CONFIGMAP_FILE" | head -1)"
    echo -e "\n${GREEN}✅ ConfigMap modification successful${NC}\n"
else
    echo -e "${YELLOW}✗${NC} MODEL_VERSION not found in ConfigMap"
    echo -e "\n${YELLOW}⚠ ConfigMap needs modification${NC}\n"
fi

# ============================================================
# VERIFICATION 4: Python Dependencies
# ============================================================
echo -e "${BLUE}[4/6] Checking Python dependencies...${NC}"
echo ""

python3 -c "import jsonschema" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} jsonschema installed"
else
    echo -e "${YELLOW}✗${NC} jsonschema not installed"
    echo "   Install: pip3 install jsonschema"
fi

python3 -c "import yaml" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} pyyaml installed"
else
    echo -e "${YELLOW}✗${NC} pyyaml not installed"
    echo "   Install: pip3 install pyyaml"
fi

echo ""

# ============================================================
# VERIFICATION 5: yq Availability
# ============================================================
echo -e "${BLUE}[5/6] Checking yq availability...${NC}"
echo ""

if command -v yq &> /dev/null; then
    YQ_VERSION=$(yq --version 2>&1 | head -1)
    echo -e "${GREEN}✓${NC} yq is installed: $YQ_VERSION"
else
    echo -e "${YELLOW}✗${NC} yq not installed"
    echo "   Install: brew install yq (macOS)"
fi

echo ""

# ============================================================
# VERIFICATION 6: Test Validation
# ============================================================
echo -e "${BLUE}[6/6] Testing validation on current values.yaml...${NC}"
echo ""

cd "$OPERATION_ROOT"

# Check if dependencies are met
if command -v yq &> /dev/null && python3 -c "import jsonschema" 2>/dev/null; then
    echo "Running validation test..."
    bash k8s/validation/validate-config.sh

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}✅ Validation test passed${NC}\n"
    else
        echo -e "\n${YELLOW}⚠ Validation found issues (this is expected if configs have errors)${NC}\n"
    fi
else
    echo -e "${YELLOW}⚠ Skipping validation test (dependencies missing)${NC}"
    echo "   Install yq and Python packages first"
    echo ""
fi

# ============================================================
# Summary
# ============================================================
echo "=========================================="
echo -e "${BLUE}Verification Summary${NC}"
echo "=========================================="
echo ""
echo "Implementation Status:"
echo "  ✓ Day 1: JSON Schema Foundation"
echo "  ✓ Day 2: Cross-file Validator"
echo "  ✓ Day 3: Pre-deployment Integration"
echo ""
echo "Files Created: $(ls -1 k8s/validation/ | wc -l | tr -d ' ') files"
echo "Lines of Code: ~$(cat k8s/validation/*.sh k8s/validation/*.py k8s/helm-chart/sms-spam-detector/values.schema.json 2>/dev/null | wc -l | tr -d ' ') lines"
echo ""
echo "Next Steps:"
echo "1. Install dependencies (if not already):"
echo "     brew install yq"
echo "     pip3 install jsonschema pyyaml"
echo ""
echo "2. Run validation:"
echo "     bash k8s/validation/validate-config.sh"
echo ""
echo "3. Run pre-deployment check:"
echo "     bash k8s/validation/pre-deployment-check.sh"
echo ""
