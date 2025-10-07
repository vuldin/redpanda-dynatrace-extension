#!/bin/bash

# Proper certificate setup using dt-cli for Dynatrace Extensions

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CERT_DIR="extension/certs"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Dynatrace Extension Certificate Setup        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check if dt command exists
if ! command -v dt &> /dev/null; then
    echo -e "${YELLOW}dt-cli not found. Install with: pipx install dt-cli${NC}"
    exit 1
fi

# Create certs directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo -e "${BLUE}Step 1: Generate CA (Certificate Authority)${NC}"
echo "This creates the root certificate that Dynatrace will trust."
echo ""

# Check if CA already exists
if [ -f "ca.pem" ] && [ -f "ca.key" ]; then
    echo -e "${YELLOW}CA certificate already exists!${NC}"
    echo ""
    read -p "Regenerate CA? This will invalidate existing developer certificates (y/n): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Press Enter when prompted for passphrase (leave empty - passwords not supported)${NC}"
        echo ""
        dt ext genca --force
    else
        echo -e "${GREEN}✓ Using existing CA certificate${NC}"
    fi
else
    echo -e "${YELLOW}Press Enter when prompted for passphrase (leave empty - passwords not supported)${NC}"
    echo ""
    dt ext genca
fi

if [ ! -f "ca.pem" ] || [ ! -f "ca.key" ]; then
    echo -e "${RED}✗ Failed to generate CA${NC}"
    exit 1
fi

echo -e "${GREEN}✓ CA certificate ready: ca.pem and ca.key${NC}"

echo ""
echo -e "${BLUE}Step 2: Generate Developer Certificate${NC}"
echo "This creates your signing certificate derived from the CA."
echo ""

# Prompt for developer name
echo -e "${YELLOW}Enter developer/organization name (e.g., 'Redpanda Developer'):${NC}"
read -r DEV_NAME

if [ -z "$DEV_NAME" ]; then
    DEV_NAME="Redpanda Extension Developer"
    echo "Using default: $DEV_NAME"
fi

# Check if dev certificate already exists
if [ -f "dev.pem" ]; then
    echo -e "${YELLOW}Developer certificate already exists!${NC}"
    echo ""
    read -p "Regenerate developer certificate? (y/n): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Using existing developer certificate${NC}"
        cd ../..

        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✓ Certificates ready!${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        echo ""
        echo "Generated files in ${BLUE}$CERT_DIR/${NC}:"
        ls -lh "$CERT_DIR"
        echo ""
        echo -e "${YELLOW}CRITICAL NEXT STEPS:${NC}"
        echo ""
        echo "1. Upload CA certificate to Dynatrace Credential Vault:"
        echo "   - File: ${BLUE}$CERT_DIR/ca.pem${NC}"
        echo "   - In Dynatrace: Settings → Credential Vault → Add → Public certificate"
        echo "   - Name it: 'redpanda-extension-ca'"
        echo ""
        echo "2. Then build and sign extension:"
        echo "   ${BLUE}./scripts/build-and-sign-dtcli.sh${NC}"
        echo ""
        exit 0
    fi
fi

dt ext generate-developer-pem --ca-crt ca.pem --ca-key ca.key -o dev.pem

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Generated developer certificate: dev.pem${NC}"
else
    echo -e "${RED}✗ Failed to generate developer certificate${NC}"
    exit 1
fi

cd ../..

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Certificates generated successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Generated files in ${BLUE}$CERT_DIR/${NC}:"
ls -lh "$CERT_DIR"
echo ""
echo -e "${YELLOW}CRITICAL NEXT STEPS:${NC}"
echo ""
echo "1. Upload CA certificate to Dynatrace Credential Vault:"
echo "   - File: ${BLUE}$CERT_DIR/ca.pem${NC}"
echo "   - In Dynatrace: Settings → Credential Vault → Add → Public certificate"
echo "   - Name it: 'redpanda-extension-ca'"
echo ""
echo "2. Upload CA certificate to ActiveGate/OneAgent hosts:"
echo "   - Copy ${BLUE}$CERT_DIR/ca.pem${NC} to hosts"
echo "   - Linux ActiveGate: /var/lib/dynatrace/remotepluginmodule/agent/conf/certificates/"
echo "   - Linux OneAgent: /var/lib/dynatrace/oneagent/agent/config/certificates/"
echo ""
echo "3. Then build and sign extension:"
echo "   ${BLUE}./scripts/build-and-sign-dtcli.sh${NC}"
echo ""
