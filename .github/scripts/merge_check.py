#!/usr/bin/env python3
"""
GitHub Action Merge Conflict Check Script

This script performs a safe no-commit merge from the current branch to the dev-main branch
and checks for conflicts. If conflicts are detected, it provides detailed error information.
"""

import subprocess
import sys
import os
import json
from typing import List, Dict, Any
from datetime import datetime

def run_command(cmd: List[str], capture_output: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(
            cmd, 
            capture_output=capture_output, 
            text=True, 
            check=False
        )
        return result
    except Exception as e:
        print(f"Error running command {' '.join(cmd)}: {e}")
        sys.exit(1)

def get_current_branch() -> str:
    """Get the current git branch name."""
    result = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
    if result.returncode != 0:
        print(f"Error getting current branch: {result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def get_conflicted_files() -> List[str]:
    """Get list of conflicted files from git status."""
    result = run_command(['git', 'status', '--porcelain'])
    if result.returncode != 0:
        print(f"Error getting git status: {result.stderr}")
        sys.exit(1)
    
    conflicted_files = []
    for line in result.stdout.strip().split('\n'):
        if line.startswith('UU ') or line.startswith('AA ') or line.startswith('DD '):
            # UU = both modified, AA = both added, DD = both deleted
            conflicted_files.append(line[3:])
    
    return conflicted_files

def parse_conflict_details(file_path: str) -> Dict[str, Any]:
    """Parse conflict details from a conflicted file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        conflicts = []
        in_conflict = False
        conflict_start = 0
        conflict_lines = []
        
        for i, line in enumerate(lines, 1):
            if line.startswith('<<<<<<<'):
                in_conflict = True
                conflict_start = i
                conflict_lines = [line]
            elif line.startswith('======='):
                conflict_lines.append(line)
            elif line.startswith('>>>>>>>'):
                conflict_lines.append(line)
                conflicts.append({
                    'start_line': conflict_start,
                    'end_line': i,
                    'lines': conflict_lines.copy()
                })
                in_conflict = False
            elif in_conflict:
                conflict_lines.append(line)
        
        return {
            'file': file_path,
            'conflicts': conflicts
        }
    except Exception as e:
        return {
            'file': file_path,
            'error': str(e),
            'conflicts': []
        }

def abort_merge():
    """Abort the current merge operation."""
    result = run_command(['git', 'merge', '--abort'])
    if result.returncode != 0:
        print(f"Warning: Could not abort merge: {result.stderr}")

def generate_conflict_report(conflicts: List[Dict], current_branch: str, target_branch: str) -> Dict[str, Any]:
    """Generate a detailed conflict report JSON structure."""
    timestamp = datetime.utcnow().isoformat() + 'Z'
    
    return {
        "report_type": "merge_conflict_check",
        "generated_at": timestamp,
        "source_branch": current_branch,
        "target_branch": target_branch,
        "status": "conflicts_detected" if conflicts else "no_conflicts",
        "total_conflicts": len(conflicts),
        "conflicts": conflicts,
        "summary": {
            "message": f"Found {len(conflicts)} merge conflict(s) when merging {current_branch} into {target_branch}",
            "action_required": "Please resolve the conflicts listed below and push again" if conflicts else "No action required",
            "resolution_steps": [
                "1. Check out your branch: git checkout {current_branch}",
                "2. Pull latest changes: git pull origin {target_branch}",
                "3. Resolve conflicts in the files listed above",
                "4. Stage resolved files: git add <resolved-files>",
                "5. Commit the merge: git commit",
                "6. Push your changes: git push origin {current_branch}"
            ] if conflicts else []
        }
    }

def save_conflict_report(report: Dict[str, Any]):
    """Save the conflict report to assets/data/merge-conflicts.json"""
    os.makedirs('assets/data', exist_ok=True)
    filepath = 'assets/data/merge-conflicts.json'
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"Conflict report saved to {filepath}")
    
    # Stage the file for commit
    result = run_command(['git', 'add', filepath])
    if result.returncode != 0:
        print(f"Warning: Could not stage conflict report: {result.stderr}")

def main():
    """Main function to perform merge conflict check."""
    # Get current branch
    current_branch = get_current_branch()
    print(f"Current branch: {current_branch}")
    
    # Define dev-main branch (adjust as needed)
    dev_main_branch = "MAIN"
    print(f"Target branch: {dev_main_branch}")
    
    # Don't run if already on dev-main branch
    if current_branch == dev_main_branch:
        print("Already on dev-main branch, no merge check needed.")
        # Set output for no conflicts
        with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
            f.write('conflicts_found=false\n')
        sys.exit(0)
    
    # Fetch latest changes
    print("Fetching latest changes...")
    result = run_command(['git', 'fetch', 'origin'])
    if result.returncode != 0:
        print(f"Error fetching changes: {result.stderr}")
        sys.exit(1)
    
    # Attempt no-commit merge using remote branches (avoid local branch switching)
    print(f"Attempting merge from {current_branch} to {dev_main_branch}...")
    result = run_command(['git', 'merge', '--no-commit', '--no-ff', f'origin/{dev_main_branch}'])
    
    # Check for conflicts regardless of merge result
    conflicted_files = get_conflicted_files()
    
    if result.returncode != 0 and not conflicted_files:
        print(f"Merge failed: {result.stderr}")
        abort_merge()
        sys.exit(1)
    
    if conflicted_files:
        print("\n" + "="*80)
        print("🚨 MERGE CONFLICTS DETECTED!")
        print("="*80)
        
        conflict_details = []
        for file_path in conflicted_files:
            details = parse_conflict_details(file_path)
            conflict_details.append(details)
            
            print(f"\n📁 File: {file_path}")
            if 'error' in details:
                print(f"   Error reading file: {details['error']}")
            else:
                print(f"   Conflicts found: {len(details['conflicts'])}")
                for i, conflict in enumerate(details['conflicts'], 1):
                    print(f"   Conflict {i}: Lines {conflict['start_line']}-{conflict['end_line']}")
        
        # Generate and save conflict report
        report = generate_conflict_report(conflict_details, current_branch, dev_main_branch)
        save_conflict_report(report)
        
        # Set output indicating conflicts were found
        with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
            f.write('conflicts_found=true\n')
        
        print("\n" + "="*80)
        print("🔧 HOW TO FIX:")
        print("="*80)
        print("1. Locally checkout your branch:")
        print(f"   git checkout {current_branch}")
        print("\n2. Pull latest changes from dev-main:")
        print(f"   git pull origin {dev_main_branch}")
        print("\n3. Resolve conflicts in the files listed above:")
        for file_path in conflicted_files:
            print(f"   - {file_path}")
        print("\n4. Stage resolved files:")
        print("   git add <resolved-files>")
        print("\n5. Complete the merge:")
        print("   git commit")
        print("\n6. Push your changes:")
        print(f"   git push origin {current_branch}")
        print("\n7. After fixing conflicts, push again to trigger this check.")
        print("="*80)
        
        # Abort the merge but don't exit with error yet
        abort_merge()
        
        # Exit with success so workflow continues to commit step
        sys.exit(0)
    else:
        print("✅ No merge conflicts detected!")
        
        # Generate and save no-conflict report
        report = generate_conflict_report([], current_branch, dev_main_branch)
        save_conflict_report(report)
        
        # Set output for no conflicts
        with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
            f.write('conflicts_found=false\n')
        
        # Abort the no-commit merge
        abort_merge()
        print("✅ Merge check completed successfully!")
        sys.exit(0) 

if __name__ == "__main__":
    main()
