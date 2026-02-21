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
import textwrap
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


def run(cmd):
    """Run shell command and return result."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()


def current_branch():
    """Get current git branch."""
    result = run_command(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
    if result.returncode == 0:
        return result.stdout.strip()
    else:
        print(f"Error getting current branch: {result.stderr}")
        return ""


def simulate_merge(branch):
    """Simulate merge from current branch to target branch."""
    print(f"Checking out target branch: {TARGET_BRANCH}")
    run(f"git checkout {TARGET_BRANCH}")
    
    print(f"Merging {branch} into {TARGET_BRANCH}...")
    result = run(f"git merge origin/{branch} --no-commit --no-ff")
    return result.returncode


def abort_merge():
    """Abort current merge operation."""
    run("git merge --abort")


def get_conflict_files():
    """Get list of conflicted files."""
    result = run("git diff --name-only --diff-filter=U")
    files = result.stdout.strip().splitlines()
    return files


def get_conflicted_files():
    """Get list of conflicted files."""
    result = run_command(['git', 'diff', '--name-only', '--diff-filter=U'])
    if result.returncode == 0:
        files = result.stdout.strip().splitlines()
        return [f for f in files if f.strip()]
    return []


def extract_conflict_details(file_path):
    """Extract detailed conflict information including code content and resolution suggestions."""
    conflicts = []
    
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()

        i = 0
        while i < len(lines):
            line_content = lines[i].rstrip('\n\r')
            
            if line_content.startswith('<<<<<<<'):
                # Extract conflict details
                conflict_start = i + 1
                
                # Get your branch code
                your_code = []
                i += 1
                while i < len(lines) and not lines[i].startswith('======='):
                    your_code.append(lines[i].rstrip())
                    i += 1
                
                # Get target branch code
                target_code = []
                i += 1  # Skip =======
                while i < len(lines) and not lines[i].startswith('>>>>>>>'):
                    target_code.append(lines[i].rstrip())
                    i += 1
                
                # Get context lines (3 before and 3 after)
                context_start = max(0, conflict_start - 3)
                context_end = min(len(lines), i + 4)
                context_lines = [lines[j].rstrip() for j in range(context_start, context_end)]
                
                # Analyze conflict and provide resolution suggestion
                resolution_prompt = analyze_conflict_and_suggest_resolution(file_path, your_code, target_code)
                
                conflicts.append({
                    'file': file_path,
                    'line': conflict_start,
                    'marker': '<<<<<<<',
                    'message': 'Incoming change marker',
                    'your_code': your_code,
                    'target_code': target_code,
                    'context_lines': context_lines,
                    'resolution_prompt': resolution_prompt,
                    'risk_level': resolution_prompt['risk_level'],
                    'suggested_action': resolution_prompt['suggested_action']
                })
                
                # Add markers for conflict boundaries
                conflicts.append({
                    'file': file_path,
                    'line': conflict_start + len(your_code),
                    'marker': '=======',
                    'message': 'Conflict separator',
                    'your_code': [],
                    'target_code': [],
                    'context_lines': [],
                    'resolution_prompt': {'message': 'Conflict separator - your code above, target code below'},
                    'risk_level': 'info',
                    'suggested_action': 'choose_version'
                })
                
                conflicts.append({
                    'file': file_path,
                    'line': i,
                    'marker': '>>>>>>>',
                    'message': 'Current branch marker',
                    'your_code': [],
                    'target_code': [],
                    'context_lines': [],
                    'resolution_prompt': {'message': 'Conflict end marker - remove after resolving'},
                    'risk_level': 'info',
                    'suggested_action': 'remove_marker'
                })
                
                print(f"::error file={file_path},line={conflict_start}::Merge Conflict Detected: {resolution_prompt['message']}")
            else:
                i += 1
                
    except Exception as e:
        print(f"::error file={file_path},line=0::Failed to read file: {str(e)}")
    
    return conflicts

def analyze_conflict_and_suggest_resolution(file_path, your_code, target_code):
    """Analyze conflict and provide intelligent resolution suggestions."""
    
    # Basic conflict analysis
    your_code_str = '\n'.join(your_code).strip()
    target_code_str = '\n'.join(target_code).strip()
    
    # Check for common conflict patterns
    if not your_code_str and target_code_str:
        return {
            'message': 'Target branch has new code, your branch has deletion',
            'risk_level': 'medium',
            'suggested_action': 'keep_target',
            'explanation': 'Your branch deleted code that exists in target branch'
        }
    elif your_code_str and not target_code_str:
        return {
            'message': 'Your branch has new code, target branch has deletion',
            'risk_level': 'low',
            'suggested_action': 'keep_your',
            'explanation': 'Your branch added new code that target branch doesn\'t have'
        }
    
    # Check for import conflicts
    if any('import' in line for line in your_code + target_code):
        return {
            'message': 'Import conflict detected',
            'risk_level': 'low',
            'suggested_action': 'merge_imports',
            'explanation': 'Combine imports from both branches to ensure all dependencies are available'
        }
    
    # Check for comment conflicts
    if all(line.strip().startswith('//') or line.strip().startswith('/*') or line.strip().startswith('*') for line in your_code + target_code if line.strip()):
        return {
            'message': 'Comment-only conflict',
            'risk_level': 'very_low',
            'suggested_action': 'keep_both',
            'explanation': 'Only comments differ - safe to merge both versions'
        }
    
    # Check for whitespace/formatting conflicts
    if your_code_str.replace(' ', '').replace('\n', '').replace('\t', '') == target_code_str.replace(' ', '').replace('\n', '').replace('\t', ''):
        return {
            'message': 'Formatting/whitespace conflict only',
            'risk_level': 'very_low',
            'suggested_action': 'format_and_merge',
            'explanation': 'Same code with different formatting - use consistent formatting'
        }
    
    # Default safe suggestion
    return {
        'message': 'Code logic conflict - manual review required',
        'risk_level': 'medium',
        'suggested_action': 'manual_merge',
        'explanation': 'Both branches have different code logic - carefully review and merge manually'
    }

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
        print(f"📤 This report will be committed to the repository for team visibility")
        print(f"🔗 Team members can pull this branch to see conflict details locally")
        
    except Exception as e:
        print(f"ERROR: Failed to save conflict report: {e}")
        import traceback
        traceback.print_exc()

def main():
    """Main function to perform merge conflict check."""
    # Get and verify current branch
    current_branch_name = current_branch()
    print(f"🔍 Detected current branch: '{current_branch_name}'")
    
    # Verify branch name is not empty or None
    if not current_branch_name or current_branch_name == "":
        print("❌ ERROR: Could not detect current branch name!")
        print("This might indicate an issue with the git repository state.")
        sys.exit(1)
    
    # Additional verification - check if we're on a valid branch
    try:
        verify_result = run("git branch --show-current")
        if verify_result.stdout.strip() != current_branch_name:
            print(f"⚠️  WARNING: Branch name mismatch detected!")
            print(f"   git rev-parse: '{current_branch_name}'")
            print(f"   git branch: '{verify_result.stdout.strip()}'")
            print("   Using git rev-parse result...")
    except:
        print("⚠️  WARNING: Could not verify branch name with git branch command")
    
    print(f"✅ Confirmed working on branch: {current_branch_name}")
    ################Target Branch Configuration##############################################################################################################################
    # Define target branch
    target_branch = "test-1"
    print(f"🎯 Target branch for merge check: {target_branch}")
    ##############################################################################################################################################################
    
    # Don't run if already on target branch
    if current_branch_name == target_branch:
        print(f"ℹ️  Skipping merge check - already on {target_branch} branch")
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
    print(f"🔄 Simulating merge: {current_branch_name} ← {target_branch}")
    print(f"   This checks if merging {target_branch} into {current_branch_name} would cause conflicts")
    print(f"   (Which is equivalent to checking if {current_branch_name} can be merged into {target_branch})")
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
        
        all_conflicts = []
        for file_path in conflicted_files:
            conflicts = extract_conflict_details(file_path)
            all_conflicts.extend(conflicts)
            
            print(f"\n📁 File: {file_path}")
            print(f"   Conflicts found: {len([c for c in conflicts if c['marker'] == '<<<<<<<'])}")
            
            # Group conflicts by conflict blocks
            conflict_blocks = [c for c in conflicts if c['marker'] == '<<<<<<<']
            for i, conflict in enumerate(conflict_blocks, 1):
                print(f"\n   🔍 Conflict {i}: Line {conflict['line']}")
                print(f"      📋 Type: {conflict['resolution_prompt']['message']}")
                print(f"      ⚠️  Risk Level: {conflict['risk_level']}")
                print(f"      💡 Suggested Action: {conflict['suggested_action']}")
                print(f"      📖 Explanation: {conflict['resolution_prompt'].get('explanation', 'No explanation available')}")
                
                print(f"\n      📝 Your Branch Code:")
                for line in conflict['your_code'][:3]:  # Show first 3 lines
                    print(f"         {line}")
                if len(conflict['your_code']) > 3:
                    print(f"         ... ({len(conflict['your_code']) - 3} more lines)")
                
                print(f"\n      📝 Target Branch Code:")
                for line in conflict['target_code'][:3]:  # Show first 3 lines
                    print(f"         {line}")
                if len(conflict['target_code']) > 3:
                    print(f"         ... ({len(conflict['target_code']) - 3} more lines)")
                
                print(f"\n      🎯 AI Chat Prompt (Copy & Paste):")
                print(f"      " + "="*60)
                
                if conflict['suggested_action'] == 'keep_your':
                    ai_prompt = f"""I have a merge conflict in {file_path} at line {conflict['line']}. 

Your branch code:
{chr(10).join(conflict['your_code'])}

Target branch code:
{chr(10).join(conflict['target_code'])}

My branch adds new functionality that doesn't exist in target. How do I resolve this conflict by keeping my changes without breaking existing functionality? Please provide the exact code to replace the conflict markers with."""
                
                elif conflict['suggested_action'] == 'keep_target':
                    ai_prompt = f"""I have a merge conflict in {file_path} at line {conflict['line']}. 

Your branch code:
{chr(10).join(conflict['your_code'])}

Target branch code:
{chr(10).join(conflict['target_code'])}

My branch deleted code that exists in target branch. How do I resolve this by keeping the target branch code without losing my other changes? Please provide the exact code to replace the conflict markers with."""
                
                elif conflict['suggested_action'] == 'merge_imports':
                    ai_prompt = f"""I have an import conflict in {file_path} at line {conflict['line']}. 

Your branch imports:
{chr(10).join([line for line in conflict['your_code'] if 'import' in line])}

Target branch imports:
{chr(10).join([line for line in conflict['target_code'] if 'import' in line])}

How do I merge these imports without breaking dependencies? Please provide the exact combined import statements to replace the conflict markers with."""
                
                elif conflict['suggested_action'] == 'keep_both':
                    ai_prompt = f"""I have a comment-only conflict in {file_path} at line {conflict['line']}. 

Your branch comments:
{chr(10).join(conflict['your_code'])}

Target branch comments:
{chr(10).join(conflict['target_code'])}

How do I safely merge both comment blocks? Please provide the exact code to replace the conflict markers with."""
                
                elif conflict['suggested_action'] == 'format_and_merge':
                    ai_prompt = f"""I have a formatting conflict in {file_path} at line {conflict['line']}. 

Your branch code:
{chr(10).join(conflict['your_code'])}

Target branch code:
{chr(10).join(conflict['target_code'])}

The code is the same but formatted differently. How do I resolve this with consistent formatting? Please provide the exact formatted code to replace the conflict markers with."""
                
                else:
                    ai_prompt = f"""I have a complex code conflict in {file_path} at line {conflict['line']}. 

Your branch code:
{chr(10).join(conflict['your_code'])}

Target branch code:
{chr(10).join(conflict['target_code'])}

Both branches have different logic. How do I resolve this without breaking functionality? Please analyze both versions and provide the exact merged code to replace the conflict markers with, explaining any compromises made."""
                
                # Wrap the prompt for better display
                wrapped_prompt = textwrap.fill(ai_prompt, width=55, subsequent_indent='      ')
                print(wrapped_prompt)
                
                print(f"\n      " + "="*60)
                print(f"      💡 Copy the prompt above and paste into AI chat")
                print(f"      🤖 The AI will give you exact code to fix the conflict")
                print(f"      ✅ Paste the AI response back into your file")
                print(f"      🧪 Test your code before committing")
            print("\n🔍 ANALYZING CODEBASE FOR ADDITIONAL ISSUES...")
            codebase_issues = []  # Placeholder for future codebase analysis
            if codebase_issues:
                print(f"📋 Found {len(codebase_issues)} codebase issues:")
                for issue in codebase_issues:
                    print(f"   - {issue['type']}: {issue['message']}")
                    print(f"     File: {issue['file']}")
                    print(f"     Line: {issue['line']}")
                
                    print(f"     Fix: {issue['suggestion']}")

        # Generate and save conflict report
        report = generate_conflict_report(all_conflicts, current_branch_name, target_branch, codebase_issues)
        save_conflict_report(report)
        
        # Set output indicating conflicts were found
        with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
            f.write('conflicts_found=true\n')
        
        print("\n" + "="*80)
        print("🔧 HOW TO FIX MERGE CONFLICTS - STEP BY STEP GUIDE")
        print("="*80)
        print()
        print("📋 UNDERSTANDING MERGE CONFLICTS:")
        print("   • Git couldn't automatically merge your changes with MAIN branch")
        print("   • You have conflicting code that needs manual resolution")
        print("   • Conflict markers show you exactly what changed")
        print()
        print("🛠️  RESOLUTION STEPS:")
        print()
        print("   1. 📥 PULL LATEST CHANGES:")
        print("      git checkout Nathi-S11")
        print("      git pull origin MAIN  # Get latest from MAIN")
        print()
        print("   2. 🔍 EXAMINE CONFLICTED FILES:")
        print("      git status  # See which files have conflicts")
        print("      Open each conflicted file in your editor")
        print()
        print("   3. 📖 READ THE CONFLICT MARKERS:")
        print("      <<<<<<< HEAD (or your branch name)")
        print("      =======  (separator)")
        print("      >>>>>>> MAIN (or other branch)")
        print()
        print("   4. ✏️  RESOLVE EACH CONFLICT:")
        print("      • Choose your version (above =======")
        print("      • Choose MAIN version (below =======") 
        print("      • Combine both versions manually")
        print("      • Remove ALL conflict markers (<<<<<<<, ======, >>>>>>>)")
        print()
        print("   5. ✅ TEST YOUR CHANGES:")
        print("      • Save the file")
        print("      • Run: flutter analyze  # Check for syntax errors")
        print("      • Run: flutter test     # Run tests if available")
        print("      • Build the app to ensure it works")
        print()
        print("   6. 📝 STAGE AND COMMIT:")
        print("      git add <resolved-file>")
        print("      git commit -m 'Resolve merge conflicts'")
        print()
        print("   7. 🚀 PUSH AND CREATE PR:")
        print("      git push origin Nathi-S11")
        print("      Create pull request to merge into MAIN")
        print()
        print("💡 PRO TIPS:")
        print("   • Don't rush - carefully review each change")
        print("   • Test thoroughly before committing")
        print("   • Ask for help if unsure about complex conflicts")
        print("   • Use git diff to see what changed")
        print()
        print("🔍 EXAMPLE CONFLICT RESOLUTION:")
        print("   BEFORE:")
        print("   <<<<<<< HEAD")
        print("       debugPrint('My version');")
        print("   =======")
        print("       debugPrint('MAIN version');")
        print("   >>>>>>> MAIN")
        print()
        print("   AFTER (choose one or combine):")
        print("       debugPrint('Combined version with both features');")
        print("="*80)
        
        # Abort the merge but don't exit with error yet
        abort_merge()
        
        # Exit with success so workflow continues to commit step
        sys.exit(0)
    else:
        print("✅ No merge conflicts detected!")
        
        # Generate and save no-conflict report
        report = generate_conflict_report([], current_branch_name, target_branch)
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
