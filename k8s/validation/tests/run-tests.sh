#!/bin/bash
# run-tests.sh - Test suite for configuration validation framework

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

echo "=========================================="
echo -e "${BLUE}Configuration Validation Test Suite${NC}"
echo "=========================================="
echo ""

# Test 1: Valid configuration should PASS
echo -e "${BLUE}[Test 1/3] Testing valid configuration...${NC}"
bash "$VALIDATION_DIR/validate-config.sh" -f "$SCRIPT_DIR/test-values-valid.yaml" --skip-schema > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} - Valid config passed validation"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Valid config should have passed"
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: Port mismatch should FAIL
echo -e "${BLUE}[Test 2/3] Testing port mismatch detection...${NC}"
bash "$VALIDATION_DIR/validate-config.sh" -f "$SCRIPT_DIR/test-values-port-mismatch.yaml" --skip-schema > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} - Port mismatch correctly detected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Port mismatch should have been caught"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: Canary tag conflict should FAIL
echo -e "${BLUE}[Test 3/3] Testing canary tag conflict detection...${NC}"
bash "$VALIDATION_DIR/validate-config.sh" -f "$SCRIPT_DIR/test-values-canary-conflict.yaml" --skip-schema > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} - Canary tag conflict correctly detected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Canary tag conflict should have been caught"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "=========================================="
echo -e "${BLUE}Test Suite Summary${NC}"
echo "=========================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
