#!/usr/bin/env python3

import subprocess
import json
import os
import sys
from datetime import datetime


REPORT_FILE = "assets/data/merge-conflicts.json"

TARGET_BRANCH = "MAIN"


def run(cmd):

    return subprocess.run(cmd, capture_output=True, text=True)


def get_branch():

    return run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"]
    ).stdout.strip()


def fetch():

    run(["git", "fetch", "origin"])


def merge():

    return run(
        ["git", "merge", "--no-commit", "--no-ff", f"origin/{TARGET_BRANCH}"]
    )


def abort():

    run(["git", "merge", "--abort"])


def get_conflicts():

    output = run(
        ["git", "status", "--porcelain"]
    ).stdout


    files = []


    for line in output.splitlines():

        if line.startswith("UU"):

            files.append(line[3:])


    return files


def extract(file):

    conflicts = []

    with open(file, encoding="utf8") as f:

        lines = f.readlines()


    start = None

    current = []


    for i, line in enumerate(lines, 1):

        if line.startswith("<<<<<<<"):

            start = i

            current = [line]


        elif start:

            current.append(line)


            if line.startswith(">>>>>>>"):

                conflicts.append({

                    "start_line": start,

                    "end_line": i,

                    "code": "".join(current)

                })

                start = None


    return {

        "file": file,

        "conflicts": conflicts

    }


def create_report(branch, conflicts):

    now = datetime.utcnow().isoformat()


    return {

        "report_id": now,

        "generated_at": now,

        "source_branch": branch,

        "target_branch": TARGET_BRANCH,

        "status":

        "conflicts_detected" if conflicts else "no_conflicts",


        "total_conflicts": len(conflicts),

        "conflicts": conflicts,


        "developer_guidance": {

            "message":

            "Resolve highlighted lines",


            "fix_steps": [

                "Open file",

                "Search <<<<<<<",

                "Edit code",

                "git add .",

                "git commit",

                "git push"

            ]

        }

    }


def save(report):

    os.makedirs("assets/data", exist_ok=True)


    with open(REPORT_FILE, "w") as f:

        json.dump(report, f, indent=2)


def set_output(conflict):

    output = os.getenv("GITHUB_OUTPUT")

    if output:

        with open(output, "a") as f:

            f.write(f"conflicts_found={'true' if conflict else 'false'}\n")


def main():

    branch = get_branch()


    if branch == TARGET_BRANCH:

        set_output(False)

        return


    fetch()

    merge()


    files = get_conflicts()


    conflicts = []


    for f in files:

        conflicts.append(extract(f))


    report = create_report(branch, conflicts)


    save(report)


    abort()


    set_output(len(conflicts) > 0)


main()
