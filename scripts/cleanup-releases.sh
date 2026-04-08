#!/bin/bash

# Script to clean up old GitHub releases
# Keeps the most recent N releases and deletes the rest

KEEP_RECENT=3  # Number of recent releases to keep

echo "Fetching releases..."

# Get all release tags sorted by creation date (newest first)
releases=$(gh release list --limit 100 --json tagName,createdAt --jq 'sort_by(.createdAt) | reverse | .[].tagName')

# Convert to array
readarray -t release_array <<< "$releases"

total=${#release_array[@]}
to_delete=$((total - KEEP_RECENT))

if [ $to_delete -le 0 ]; then
    echo "You have $total releases. Nothing to delete (keeping $KEEP_RECENT most recent)."
    exit 0
fi

echo "Found $total releases. Will delete $to_delete old releases (keeping $KEEP_RECENT most recent)."
echo ""
echo "Releases to keep:"
for i in $(seq 0 $((KEEP_RECENT - 1))); do
    if [ $i -lt $total ]; then
        echo "  - ${release_array[$i]}"
    fi
done

echo ""
echo "Releases to delete:"
for i in $(seq $KEEP_RECENT $((total - 1))); do
    echo "  - ${release_array[$i]}"
done

echo ""
read -p "Do you want to proceed with deletion? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Deleting old releases..."

for i in $(seq $KEEP_RECENT $((total - 1))); do
    tag="${release_array[$i]}"
    echo "Deleting release: $tag"
    gh release delete "$tag" --yes --cleanup-tag
done

echo ""
echo "Done! Deleted $to_delete releases."
