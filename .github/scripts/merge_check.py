#!/usr/bin/env python3
"""
GitHub Action Merge Conflict Check Script

This script performs a safe no-commit merge from the current branch to the MAIN branch
and checks for conflicts. If conflicts are detected, it provides detailed error information.
"""

import subprocess
import sys
import os
import json
from typing import List, Dict, Any
from datetime import datetime

def run_command(cmd: List[str], capture_output: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return result."""
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
    """Get current git branch name."""
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
    """Abort current merge operation."""
    result = run_command(['git', 'merge', '--abort'])
    if result.returncode != 0:
        print(f"Warning: Could not abort merge: {result.stderr}")

def analyze_codebase_issues() -> List[Dict[str, Any]]:
    """Analyze codebase for common issues and errors."""
    issues = []
    
    # Check for common Dart/Flutter issues
    dart_files = []
    try:
        result = run_command(['find', '.', '-name', '*.dart', '-type', 'f'])
        if result.returncode == 0:
            dart_files = result.stdout.strip().split('\n')
    except:
        pass
    
    for dart_file in dart_files:
        if dart_file.startswith('./.git/') or dart_file.startswith('./build/'):
            continue
            
        try:
            with open(dart_file, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
                lines = content.split('\n')
                
                for i, line in enumerate(lines, 1):
                    line_stripped = line.strip()
                    
                    # Check for undefined references
                    if 'TeamChatButton(' in line and 'TeamChatButton' not in content:
                        issues.append({
                            'type': 'UNDEFINED_REFERENCE',
                            'message': 'TeamChatButton is not defined',
                            'file': dart_file,
                            'line': i,
                            'suggestion': 'Import or define TeamChatButton widget'
                        })
                    
                    # Check for missing imports
                    if 'import ' in line and ';' in line:
                        import_match = line.strip().split("import ")[1].split(";")[0].strip()
                        if import_match and not any(import_match in content for imp in content.split('\n') if 'import ' in imp):
                            issues.append({
                                'type': 'MISSING_IMPORT',
                                'message': f'Import {import_match} may be missing or unused',
                                'file': dart_file,
                                'line': i,
                                'suggestion': 'Check import statement and file existence'
                            })
                    
                    # Check for syntax errors
                    if line_stripped.endswith(')') and not line_stripped.endswith(';') and 'class ' in line:
                        issues.append({
                            'type': 'SYNTAX_ERROR',
                            'message': 'Missing semicolon after class declaration',
                            'file': dart_file,
                            'line': i,
                            'suggestion': 'Add semicolon at end of line'
                        })
                    
                    # Check for missing async/await
                    if 'Future<' in line and 'await ' not in content and 'async ' not in content:
                        issues.append({
                            'type': 'ASYNC_ISSUE',
                            'message': 'Future detected but missing async/await',
                            'file': dart_file,
                            'line': i,
                            'suggestion': 'Add async keyword or await the Future'
                        })
                        
        except Exception as e:
            issues.append({
                'type': 'FILE_READ_ERROR',
                'message': f'Cannot read file {dart_file}: {str(e)}',
                'file': dart_file,
                'line': 0,
                'suggestion': 'Check file permissions and encoding'
            })
    
    # Check for workflow issues
    workflow_files = ['.github/workflows/test-merge-conflicts.yml', '.github/workflows/generate-commits.yml']
    for workflow_file in workflow_files:
        try:
            with open(workflow_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
                # Check for deprecated set-output
                if '::set-output' in content and 'GITHUB_OUTPUT' not in content:
                    issues.append({
                        'type': 'DEPRECATED_GITHUB_ACTION',
                        'message': 'Using deprecated ::set-output command',
                        'file': workflow_file,
                        'line': 0,
                        'suggestion': 'Use GITHUB_OUTPUT file instead'
                    })
                    
                # Check for missing permissions
                if 'contents: write' not in content and 'git push' in content:
                    issues.append({
                        'type': 'MISSING_PERMISSIONS',
                        'message': 'Workflow missing contents: write permission',
                        'file': workflow_file,
                        'line': 0,
                        'suggestion': 'Add permissions: contents: write'
                    })
                    
        except Exception as e:
            issues.append({
                'type': 'WORKFLOW_READ_ERROR',
                'message': f'Cannot read workflow {workflow_file}: {str(e)}',
                'file': workflow_file,
                'line': 0,
                'suggestion': 'Check workflow file syntax'
            })
    
    return issues

def generate_conflict_report(conflicts: List[Dict], current_branch: str, target_branch: str, codebase_issues: List[Dict] = None) -> Dict[str, Any]:
    """Generate a detailed conflict report JSON structure."""
    timestamp = datetime.utcnow().isoformat() + 'Z'
    
    return {
        "report_type": "merge_conflict_check",
        "generated_at": timestamp,
        "source_branch": current_branch,
        "target_branch": target_branch,
        "status": "conflicts_detected" if conflicts or codebase_issues else "no_conflicts",
        "total_conflicts": len(conflicts),
        "conflicts": conflicts,
        "codebase_issues": codebase_issues or [],
        "summary": {
            "message": f"Found {len(conflicts)} merge conflict(s) and {len(codebase_issues or [])} codebase issue(s) when merging {current_branch} into {target_branch}",
            "action_required": "Please resolve conflicts and fix codebase issues listed below" if conflicts or codebase_issues else "No action required",
            "resolution_steps": [
                "1. Check out your branch: git checkout {current_branch}",
                "2. Pull latest changes: git pull origin {target_branch}",
                "3. Resolve conflicts in files listed above",
                "4. Fix codebase issues highlighted below",
                "5. Stage resolved files: git add <resolved-files>",
                "6. Commit the merge: git commit",
                "7. Push your changes: git push origin {current_branch}"
            ] if conflicts or codebase_issues else []
        }
    }

def save_conflict_report(report: Dict[str, Any]):
    """Save conflict report to assets/data/merge-conflicts.json"""
    try:
        os.makedirs('assets/data', exist_ok=True)
        filepath = 'assets/data/merge-conflicts.json'
        
        print(f"DEBUG: Saving conflict report to {filepath}")
        print(f"DEBUG: Report status: {report.get('status', 'unknown')}")
        print(f"DEBUG: Total conflicts: {report.get('total_conflicts', 0)}")
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Conflict report saved to {filepath}")
        
        # Verify file was written
        if os.path.exists(filepath):
            print(f"DEBUG: File exists and size: {os.path.getsize(filepath)} bytes")
        else:
            print(f"ERROR: File was not created at {filepath}")
        
        # Note: File is saved but not staged - workflow will handle staging
        
    except Exception as e:
        print(f"ERROR: Failed to save conflict report: {e}")
        import traceback
        traceback.print_exc()

def main():
    """Main function to perform merge conflict check."""
    # Get current branch
    current_branch = get_current_branch()
    print(f"Current branch: {current_branch}")
    ################Target Branch Configuration##############################################################################################################################
    # Define target branch
    target_branch = "Nathi-S11"
    print(f"Target branch: {target_branch}")
    ##############################################################################################################################################################
    
    # Don't run if already on target branch
    if current_branch == target_branch:
        print("Already on MAIN branch, no merge check needed.")
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
    
    # Attempt no-commit merge using remote branches
    print(f"Attempting merge from {current_branch} to {target_branch}...")
    result = run_command(['git', 'merge', '--no-commit', '--no-ff', f'origin/{target_branch}'])
    
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
        
        # Check for additional codebase issues
        print("\n🔍 ANALYZING CODEBASE FOR ADDITIONAL ISSUES...")
        codebase_issues = analyze_codebase_issues()
        if codebase_issues:
            print(f"📋 Found {len(codebase_issues)} codebase issues:")
            for issue in codebase_issues:
                print(f"   - {issue['type']}: {issue['message']}")
                print(f"     File: {issue['file']}")
                print(f"     Line: {issue['line']}")
                if 'suggestion' in issue:
                    print(f"     Fix: {issue['suggestion']}")
        
        # Generate and save conflict report
        report = generate_conflict_report(conflict_details, current_branch, target_branch, codebase_issues)
        save_conflict_report(report)
        
        # Set output indicating conflicts were found
        with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
            f.write('conflicts_found=true\n')
        
        print("\n" + "="*80)
        print("🔧 HOW TO FIX:")
        print("="*80)
        print("1. Locally checkout your branch:")
        print(f"   git checkout {current_branch}")
        print("\n2. Pull latest changes from MAIN:")
        print(f"   git pull origin {target_branch}")
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
        report = generate_conflict_report([], current_branch, target_branch)
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
