#!/usr/bin/env python3
"""
Production GitHub Action Merge Conflict Detection Script

Fully compatible with testMergeConflicts.yml workflow.

Features:
• Safe no-commit merge
• Detailed JSON conflict report
• Always generates unique JSON (prevents Git "no changes" issue)
• Sets GitHub Actions outputs correctly
• Fully CI/CD safe
"""

import subprocess
import sys
import os
import json
from datetime import datetime
from typing import List, Dict, Any


REPORT_FILE = "assets/data/merge-conflicts.json"
TARGET_BRANCH = "MAIN"


# ---------------------------------------------------
# Utilities
# ---------------------------------------------------

def run_command(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)


def write_output(conflicts_found: bool):

    github_output = os.getenv("GITHUB_OUTPUT")

    if github_output:
        with open(github_output, "a") as f:
            f.write(f"conflicts_found={'true' if conflicts_found else 'false'}\n")


# ---------------------------------------------------
# Git helpers
# ---------------------------------------------------

def get_current_branch():

    result = run_command(["git", "rev-parse", "--abbrev-ref", "HEAD"])

    if result.returncode != 0:
        print(result.stderr)
        sys.exit(1)

    return result.stdout.strip()


def fetch():

    run_command(["git", "fetch", "origin"])


def abort_merge():

    run_command(["git", "merge", "--abort"])


def merge_target():

    return run_command(
        ["git", "merge", "--no-commit", "--no-ff", f"origin/{TARGET_BRANCH}"]
    )


# ---------------------------------------------------
# Conflict Detection
# ---------------------------------------------------

def get_conflicted_files():

    result = run_command(["git", "status", "--porcelain"])

    conflicts = []

    for line in result.stdout.splitlines():

        if line.startswith(("UU", "AA", "DD")):

            conflicts.append(line[3:])

    return conflicts


def parse_conflicts(file_path):

    conflict_blocks = []

    try:

        with open(file_path, encoding="utf-8") as f:

            lines = f.readlines()

        start = None

        for i, line in enumerate(lines, 1):

            if line.startswith("<<<<<<<"):

                start = i

            elif line.startswith(">>>>>>>") and start:

                conflict_blocks.append({
                    "start_line": start,
                    "end_line": i
                })

                start = None

    except Exception as e:

        return {

            "file": file_path,
            "error": str(e),
            "conflicts": []

        }

    return {

        "file": file_path,
        "conflicts": conflict_blocks

    }


# ---------------------------------------------------
# Report Generation
# ---------------------------------------------------

def generate_report(conflicts, source):

    timestamp = datetime.utcnow().isoformat()

    return {

        "report_id": timestamp,

        "generated_at": timestamp,

        "source_branch": source,

        "target_branch": TARGET_BRANCH,

        "status": "conflicts_detected" if conflicts else "no_conflicts",

        "total_conflicts": len(conflicts),

        "conflicts": conflicts,

        "developer_guidance": {

            "message":

            "Pull latest MAIN and resolve conflicts locally",

            "commands": [

                f"git checkout {source}",

                f"git pull origin {TARGET_BRANCH}",

                "resolve conflicts",

                "git add .",

                "git commit",

                f"git push origin {source}"

            ]

        }

    }


def save_report(report):

    os.makedirs("assets/data", exist_ok=True)

    with open(REPORT_FILE, "w", encoding="utf-8") as f:

        json.dump(report, f, indent=2)

    print(f"Report saved: {REPORT_FILE}")

    print(f"Size: {os.path.getsize(REPORT_FILE)} bytes")


# ---------------------------------------------------
# Main
# ---------------------------------------------------

def main():

    branch = get_current_branch()

    print(f"Source branch: {branch}")


    if branch == TARGET_BRANCH:

        print("Skipping MAIN")

        write_output(False)

        sys.exit(0)


    fetch()

    merge_target()

    conflicted_files = get_conflicted_files()


    conflicts = []

    for file in conflicted_files:

        conflicts.append(parse_conflicts(file))


    report = generate_report(conflicts, branch)

    save_report(report)


    abort_merge()


    if conflicts:

        print("Conflicts detected")

        write_output(True)

    else:

        print("No conflicts")

        write_output(False)


    sys.exit(0)


if __name__ == "__main__":

    main()
