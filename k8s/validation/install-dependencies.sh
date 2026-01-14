#!/bin/bash
# install-dependencies.sh - Install validation framework dependencies

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo -e "${BLUE}Configuration Validation Framework${NC}"
echo -e "${BLUE}Dependency Installation${NC}"
echo "=========================================="
echo ""

# Check for yq
echo -e "${BLUE}[1/2] Checking yq installation...${NC}"
if command -v yq &> /dev/null; then
    echo -e "${GREEN}✓${NC} yq already installed ($(yq --version))"
else
    echo -e "${YELLOW}⚠${NC} yq not found, attempting to install..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install yq
            echo -e "${GREEN}✓${NC} yq installed via Homebrew"
        else
            echo -e "${RED}✗${NC} Homebrew not found. Please install yq manually:"
            echo "   Visit: https://github.com/mikefarah/yq#install"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y yq
            echo -e "${GREEN}✓${NC} yq installed via apt-get"
        elif command -v snap &> /dev/null; then
            sudo snap install yq
            echo -e "${GREEN}✓${NC} yq installed via snap"
        else
            echo -e "${RED}✗${NC} Package manager not found. Please install yq manually:"
            echo "   Visit: https://github.com/mikefarah/yq#install"
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Unsupported OS. Please install yq manually:"
        echo "   Visit: https://github.com/mikefarah/yq#install"
        exit 1
    fi
fi
echo ""

# Check for Python dependencies
echo -e "${BLUE}[2/2] Checking Python dependencies...${NC}"

if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    echo -e "${GREEN}✓${NC} Python 3 found: $PYTHON_VERSION"

    # Check if PyYAML is installed
    if python3 -c "import yaml" &> /dev/null; then
        echo -e "${GREEN}✓${NC} pyyaml already installed"
    else
        echo -e "${YELLOW}⚠${NC} Installing pyyaml..."
        pip3 install pyyaml
    fi

    # Check if jsonschema is installed
    if python3 -c "import jsonschema" &> /dev/null; then
        echo -e "${GREEN}✓${NC} jsonschema already installed"
    else
        echo -e "${YELLOW}⚠${NC} Installing jsonschema..."
        pip3 install jsonschema
    fi

    echo -e "${GREEN}✓${NC} Python dependencies installed"
else
    echo -e "${RED}✗${NC} Python 3 not found. Please install Python 3.8 or higher"
    exit 1
fi
echo ""

echo "=========================================="
echo -e "${GREEN}✅ All dependencies installed!${NC}"
echo "=========================================="
echo ""
echo "You can now run:"
echo "  bash k8s/validation/validate-config.sh"
echo "  bash k8s/validation/pre-deployment-check.sh"
echo ""
