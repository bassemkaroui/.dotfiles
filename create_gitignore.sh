#!/bin/bash

# Function to ignore nested Git repositories
ignore_nested_repos() {
    # Find all Git repositories recursively
    nested_repos=$(find . -type d -name ".git")
    
    touch .gitignore
    # Iterate over found repositories
    for repo in $nested_repos; do
        # Get the parent directory of the .git directory
        parent_dir=$(dirname $repo)

        if [ "$parent_dir" != "." ]; then
            # Remove the '.' prefix
            parent_dir=$(echo "$parent_dir" | sed 's|^.||')
            # Check if the directory is already in .gitignore
            if ! grep -q "^$parent_dir/" .gitignore; then
                # Add the parent directory to .gitignore
                echo "$parent_dir/" >> .gitignore
            fi
        fi
    done
}

# Call the function to ignore nested repositories
ignore_nested_repos
