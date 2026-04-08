#!/bin/bash

# Script to clean up GitHub Actions workflow runs

echo "GitHub Actions Cleanup"
echo "====================="
echo ""

# List workflows
echo "Available workflows:"
gh workflow list
echo ""

read -p "Enter workflow name (or press Enter to clean ALL workflows): " workflow_name

if [ -z "$workflow_name" ]; then
    echo "Fetching all workflow runs..."
    runs=$(gh run list --limit 1000 --json databaseId,status,conclusion,createdAt,name --jq '.[] | "\(.databaseId)|\(.name)|\(.status)|\(.conclusion)|\(.createdAt)"')
else
    echo "Fetching runs for workflow: $workflow_name"
    runs=$(gh run list --workflow "$workflow_name" --limit 1000 --json databaseId,status,conclusion,createdAt,name --jq '.[] | "\(.databaseId)|\(.name)|\(.status)|\(.conclusion)|\(.createdAt)"')
fi

if [ -z "$runs" ]; then
    echo "No workflow runs found."
    exit 0
fi

# Count runs
total=$(echo "$runs" | wc -l)
echo "Found $total workflow runs."
echo ""

echo "What would you like to delete?"
echo "1) All runs"
echo "2) Only completed runs"
echo "3) Only failed runs"
echo "4) Runs older than X days"
echo "5) Cancel"
echo ""
read -p "Choose option (1-5): " option

case $option in
    1)
        run_ids=$(echo "$runs" | cut -d'|' -f1)
        ;;
    2)
        run_ids=$(echo "$runs" | awk -F'|' '$3=="completed" {print $1}')
        ;;
    3)
        run_ids=$(echo "$runs" | awk -F'|' '$4=="failure" {print $1}')
        ;;
    4)
        read -p "Delete runs older than how many days? " days
        cutoff_date=$(date -d "$days days ago" +%s 2>/dev/null || date -v-${days}d +%s)
        run_ids=$(echo "$runs" | while IFS='|' read -r id name status conclusion created; do
            run_date=$(date -d "$created" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +%s)
            if [ $run_date -lt $cutoff_date ]; then
                echo $id
            fi
        done)
        ;;
    5)
        echo "Cancelled."
        exit 0
        ;;
    *)
        echo "Invalid option."
        exit 1
        ;;
esac

if [ -z "$run_ids" ]; then
    echo "No runs match the criteria."
    exit 0
fi

count=$(echo "$run_ids" | wc -l)
echo ""
echo "Will delete $count workflow runs."
read -p "Proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Deleting workflow runs..."
echo "$run_ids" | while read -r id; do
    echo "Deleting run $id..."
    gh run delete "$id" 2>/dev/null
done

echo ""
echo "Done! Deleted $count workflow runs."
