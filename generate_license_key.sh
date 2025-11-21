#!/bin/bash

# EchoTune License Key Generator
# This script generates valid license keys for EchoTune

echo "EchoTune License Key Generator"
echo "=============================="
echo ""

# Function to generate a random 5-character segment
generate_segment() {
    cat /dev/urandom | LC_ALL=C tr -dc 'A-Z0-9' | fold -w 5 | head -n 1
}

echo "Choose license type:"
echo "1) Demo License (Lifetime Pro - any key starting with 'DEMO-')"
echo "2) Individual License (1 year - format: XXXXX-XXXXX-XXXXX-XXXXX)"
echo ""
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        # Demo license - just needs to start with DEMO-
        demo_key="DEMO-$(generate_segment)-$(generate_segment)-$(generate_segment)"
        echo ""
        echo "✓ Demo License Key (Lifetime Pro):"
        echo "$demo_key"
        echo ""
        echo "This key will activate a Pro tier lifetime license."
        ;;
    2)
        # Regular individual license
        segment1=$(generate_segment)
        segment2=$(generate_segment)
        segment3=$(generate_segment)
        segment4=$(generate_segment)
        regular_key="$segment1-$segment2-$segment3-$segment4"
        echo ""
        echo "✓ Individual License Key (1 year):"
        echo "$regular_key"
        echo ""
        echo "This key will activate an Individual tier license valid for 1 year."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "Copy the license key above and paste it into EchoTune when prompted."





