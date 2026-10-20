#!/usr/bin/env python3
"""Fail closed when GitHub environment protection cannot be verified. Read-only API."""
import json
import os
import subprocess
import sys

REPOSITORY = 'sfc-gh-dshemsi/snowflake-sql-cicd-demo'


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path], text=True))


def validate(environment, branches, target, approvals=None):
    policy = environment.get('deployment_branch_policy') or {}
    if policy != {'protected_branches': False, 'custom_branch_policies': True}:
        raise ValueError('Custom main-only environment policy is required')
    rules = branches.get('branch_policies', [])
    if len(rules) != 1 or rules[0].get('name') != 'main' or rules[0].get('type') != 'branch':
        raise ValueError('Exactly one branch rule for main is required; tags are not allowed')
    if target == 'prod':
        reviewer_rules = [rule for rule in environment.get('protection_rules', [])
                          if rule.get('type') == 'required_reviewers']
        if not reviewer_rules or not any(
            reviewer.get('reviewer', {}).get('id') == 216220113
            for rule in reviewer_rules for reviewer in rule.get('reviewers', [])
        ):
            raise ValueError('Production required reviewer is absent')
        if environment.get('can_admins_bypass') is not False:
            raise ValueError('Disable production administrator bypass')
        # Native approval is the security gate. Confirm this run actually received it.
        if not any(entry.get('state') == 'approved'
                   and entry.get('user', {}).get('id') == 216220113
                   and any(item.get('name') == 'prod' for item in entry.get('environments', []))
                   for entry in (approvals or [])):
            raise ValueError('No production approval by the configured reviewer on this run')


if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) == 2 else ''
    if target not in {'dev', 'qa', 'prod'} or os.environ.get('GITHUB_REPOSITORY') != REPOSITORY:
        raise SystemExit('Unexpected repository or environment')
    base = f'repos/{REPOSITORY}'
    try:
        approvals = api(f'{base}/actions/runs/{os.environ["GITHUB_RUN_ID"]}/approvals') if target == 'prod' else None
        validate(api(f'{base}/environments/{target}'),
                 api(f'{base}/environments/{target}/deployment-branch-policies'),
                 target, approvals)
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'Environment protection verification failed: {error}')
    print(f'PASS: {target} environment protections verified')
