#!/bin/bash

# Build and sign extension using dt-cli

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CERT_DIR="extension/certs"
DEV_CERT="$CERT_DIR/dev.pem"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Build and Sign Extension with dt-cli         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if developer certificate exists
if [ ! -f "$DEV_CERT" ]; then
    echo -e "${RED}✗ Developer certificate not found: $DEV_CERT${NC}"
    echo "Run: ./scripts/setup-certificates-dtcli.sh"
    exit 1
fi

echo -e "${BLUE}[1/3] Building extension...${NC}"

# Extract version from extension.yaml
VERSION=$(grep "^version:" extension/extension.yaml | awk '{print $2}')

if [ -z "$VERSION" ]; then
    echo -e "${RED}✗ Could not extract version from extension.yaml${NC}"
    exit 1
fi

echo "Building version: $VERSION"
echo ""

# Clean up any existing build artifacts
rm -f extension.zip bundle.zip

# Build from extension directory
dt ext assemble --src extension --output extension.zip

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Extension built: extension.zip${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[2/3] Signing extension...${NC}"
dt ext sign --src extension.zip --key "$DEV_CERT" --output bundle.zip

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Extension signed: bundle.zip${NC}"
else
    echo -e "${RED}✗ Signing failed${NC}"
    exit 1
fi

# Move bundle to dist
PACKAGE_NAME="custom:redpanda.enhanced-${VERSION}-signed.zip"
mkdir -p dist
mv bundle.zip "dist/$PACKAGE_NAME"
rm -f extension.zip  # Clean up intermediate file

echo ""
echo -e "${BLUE}[3/3] Ready to upload${NC}"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Extension ready for upload!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Package: ${BLUE}dist/$PACKAGE_NAME${NC}"
echo ""
echo -e "${YELLOW}Upload to Dynatrace:${NC}"
echo ""
echo "Option 1 - Via dt-cli:"
echo "  dt ext upload dist/$PACKAGE_NAME \\"
echo "    --tenant-url https://hvs38795.live.dynatrace.com \\"
echo "    --api-token YOUR_TOKEN"
echo ""
echo "Option 2 - Via Custom Extensions Creator:"
echo "  1. Upload the signed bundle.zip file"
echo "  2. It should accept it since it's signed with your CA certificate"
echo ""
echo -e "${YELLOW}Remember: CA certificate must be uploaded to Credential Vault first!${NC}"
echo ""
