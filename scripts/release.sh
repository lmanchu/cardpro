#!/bin/bash
# CardPro Release Script
# Usage: ./scripts/release.sh [major|minor|patch|build]

set -e

cd "$(dirname "$0")/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== CardPro Release Script ===${NC}"

# Read current version from project.yml
CURRENT_VERSION=$(grep 'MARKETING_VERSION:' project.yml | sed 's/.*"\(.*\)"/\1/')
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/.*"\(.*\)"/\1/')

echo "Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"

# Determine version bump type
BUMP_TYPE=${1:-build}

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        NEW_BUILD=1
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        NEW_BUILD=1
        ;;
    patch)
        PATCH=$((PATCH + 1))
        NEW_BUILD=1
        ;;
    build)
        NEW_BUILD=$((CURRENT_BUILD + 1))
        ;;
    *)
        echo -e "${RED}Invalid bump type: $BUMP_TYPE${NC}"
        echo "Usage: $0 [major|minor|patch|build]"
        exit 1
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo -e "${YELLOW}New version: $NEW_VERSION (build $NEW_BUILD)${NC}"
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Update project.yml
echo -e "${GREEN}Updating project.yml...${NC}"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$NEW_VERSION\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/" project.yml

# Regenerate Xcode project
echo -e "${GREEN}Regenerating Xcode project...${NC}"
xcodegen generate

# Clean and Archive
echo -e "${GREEN}Archiving...${NC}"
rm -rf ~/Desktop/CardPro.xcarchive
xcodebuild -project CardPro.xcodeproj \
    -scheme CardPro \
    -destination 'generic/platform=iOS' \
    -archivePath ~/Desktop/CardPro.xcarchive \
    archive \
    | grep -E "(error:|warning:|ARCHIVE SUCCEEDED|ARCHIVE FAILED)"

if [ ! -d ~/Desktop/CardPro.xcarchive ]; then
    echo -e "${RED}Archive failed!${NC}"
    exit 1
fi

# Upload to App Store Connect
echo -e "${GREEN}Uploading to App Store Connect...${NC}"
xcodebuild -exportArchive \
    -archivePath ~/Desktop/CardPro.xcarchive \
    -exportPath ~/Desktop/CardProExport \
    -exportOptionsPlist /tmp/ExportOptions.plist \
    | grep -E "(error:|Upload succeeded|EXPORT SUCCEEDED|EXPORT FAILED)"

echo ""
echo -e "${GREEN}=== Release Complete ===${NC}"
echo -e "Version: ${YELLOW}$NEW_VERSION (build $NEW_BUILD)${NC}"
echo ""
echo "Next steps:"
echo "1. Wait 5-10 minutes for App Store Connect to process"
echo "2. Select the new build in App Store Connect"
echo "3. Submit for review"
