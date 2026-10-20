"""Offline contract tests. These never connect to Snowflake or invoke deployment SQL."""
import importlib.util
import json
import os
import tempfile
from pathlib import Path
import re
import subprocess
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class OfflineContracts(unittest.TestCase):
    def test_mock_cli_failure_propagates_and_order_is_preserved(self):
        # Temporary executables simulate git/snow; no actual SQL or network call occurs.
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            (temp / 'git').write_text('#!/bin/sh\nprintf "%s\\n" "$DEPLOY_SHA"\n')
            (temp / 'snow').write_text(
                '#!/usr/bin/env python3\nimport json, os, sys\n'
                'with open(os.environ["CAPTURE_ARGS"], "w") as output: json.dump(sys.argv[1:], output)\n'
                'sys.exit(int(os.environ["MOCK_EXIT"]))\n')
            for name in ['git', 'snow']:
                (temp / name).chmod(0o700)
            env = dict(os.environ, PATH=directory + os.pathsep + os.environ['PATH'],
                       GITHUB_ACTIONS='true', GITHUB_REPOSITORY='sfc-gh-dshemsi/snowflake-sql-cicd-demo',
                       SNOWFLAKE_ACCOUNT='SFSENORTHAMERICA-DSHEMSI_AWS1',
                       SNOWFLAKE_AUTHENTICATOR='WORKLOAD_IDENTITY', SNOWFLAKE_WORKLOAD_IDENTITY_PROVIDER='OIDC',
                       DEPLOY_SHA='a' * 40, GITHUB_RUN_ID='1', GITHUB_RUN_ATTEMPT='1',
                       GITHUB_EVENT_NAME='pull_request', CAPTURE_ARGS=str(temp / 'arguments.json'))
            for exit_code in [0, 5]:
                result = subprocess.run(['bash', str(ROOT / 'scripts/deploy.sh'), 'pr'],
                                        env=dict(env, MOCK_EXIT=str(exit_code)), capture_output=True)
                self.assertEqual(result.returncode, exit_code)
                arguments = json.loads((temp / 'arguments.json').read_text())
                files = [Path(arguments[index + 1]).name for index, value in enumerate(arguments) if value == '-f']
                self.assertEqual(files[0:2], ['00_guard.sql', 'isolation.sql'])
                self.assertEqual(files.count('10_raw_tables.sql'), 2)
                self.assertEqual(files[-3:], ['assert_raw_preserved.sql', 'assertions.sql', '90_record_release.sql'])
                self.assertIn('bronze=CI_BRONZE', arguments)
                self.assertIn('role=RETAIL_PR_DEPLOY', arguments)

    def test_procedure_copy_grants_position(self):
        text = (ROOT / 'sql/60_process_orders.sql').read_text()
        self.assertLess(text.index('COPY GRANTS'), text.index('RETURNS'))

    def test_setup_requires_no_generator(self):
        self.assertFalse((ROOT / 'scripts/build_setup.py').exists())
        for filename in ['setup.sql', 'README.md']:
            self.assertNotIn('build_setup.py', (ROOT / filename).read_text())
        for path in (ROOT / '.github/workflows').glob('*.yml'):
            self.assertNotIn('build_setup.py', path.read_text())

    def test_setup_is_self_contained(self):
        text = (ROOT / 'setup.sql').read_text()
        code = re.sub(r'--[^\n]*', '', text)
        self.assertNotRegex(code, r'\b(EXECUTE IMMEDIATE|DECLARE|BEGIN|RAISE)\b')
        self.assertNotIn('$$', code)
        self.assertEqual(re.findall(r'^-- (\d+)\.', text, re.M),
                         [str(number) for number in range(1, 10)])
        self.assertIn('SET USERNAME = (SELECT CURRENT_USER());', code)
        self.assertIn('TO USER IDENTIFIER($USERNAME);', code)
        self.assertNotIn('<%', code)
        self.assertNotIn('/*', code)
        self.assertNotIn('EXECUTE IMMEDIATE FROM', code)
        for environment in ['PR', 'DEV', 'QA', 'PROD']:
            self.assertIn(f'CREATE USER IF NOT EXISTS RETAIL_{environment}_SVC', code)
            self.assertRegex(code, rf'ALTER USER RETAIL_{environment}_SVC\s+SET NETWORK_POLICY = RETAIL_GITHUB_RUNNERS;')
        self.assertIn('CREATE API INTEGRATION IF NOT EXISTS RETAIL_GITHUB_APP', code)
        self.assertIn('BLOCKED_NETWORK_RULE_LIST = ()', code)
        self.assertNotIn('ALTER ACCOUNT', code)
        self.assertNotIn('ALTER USER DSHEMSI', code)
        self.assertNotIn('DISABLED = FALSE', code)
        self.assertIn('TYPE = SERVICE DISABLED = TRUE', code)
        self.assertNotRegex(code, r'\b(DROP|TRUNCATE)\b')
        self.assertLess(code.index('SHOW PARAMETERS LIKE \'NETWORK_POLICY\' IN ACCOUNT'),
                        code.index('CREATE ROLE'))
        self.assertLess(code.index('DESC NETWORK POLICY RETAIL_GITHUB_RUNNERS'),
                        code.index('ALTER USER RETAIL_PR_SVC'))
        self.assertGreater(code.index("SELECT 'Setup script finished"), code.index('CREATE API INTEGRATION'))
        self.assertIn('they do NOT automatically stop writes', text)
        self.assertIn('BEFORE running the ALTER USER', text)
        self.assertNotRegex(code, r'\bCREATE\s+OR\s+REPLACE\b')

    def test_setup_data_matches_deployment(self):
        text = (ROOT / 'setup.sql').read_text()
        for filename in ['sql/10_raw_tables.sql', 'sql/20_seed.sql']:
            expected = (ROOT / filename).read_text()
            for key, value in {'database': 'DEV_DB', 'bronze': 'BRONZE'}.items():
                expected = expected.replace(f'<% {key} %>', value)
            self.assertIn(expected, text)

    def test_shell_syntax(self):
        for path in (ROOT / 'scripts').glob('*.sh'):
            subprocess.run(['bash', '-n', str(path)], check=True)

    def test_local_deployment_refused(self):
        result = subprocess.run(['bash', str(ROOT / 'scripts/deploy.sh'), 'dev'],
                                env={'PATH': '/usr/bin:/bin'}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('GitHub Actions only', result.stderr)

    def test_bad_targets_refused(self):
        for target in ['', 'DEV_DB', 'snowhouse', 'prod; DROP DATABASE DEV_DB']:
            result = subprocess.run(['bash', str(ROOT / 'scripts/deploy.sh'), target],
                                    capture_output=True)
            self.assertEqual(result.returncode, 2)

    def test_no_destructive_storage_or_admin_in_deployment(self):
        forbidden = r'\b(?:DROP\s+(?:TABLE|DATABASE|SCHEMA)|TRUNCATE|CREATE\s+OR\s+REPLACE\s+TABLE|GRANT|CREATE\s+USER|ALTER\s+USER)\b'
        for path in (ROOT / 'sql').glob('*.sql'):
            code = re.sub(r'--[^\n]*', '', path.read_text())
            self.assertIsNone(re.search(forbidden, code, re.I), str(path))
        self.assertNotIn('RESUME;', (ROOT / 'sql/80_task.sql').read_text())

    def test_business_templates_are_environment_neutral(self):
        keys = {'database', 'bronze', 'silver', 'gold', 'role', 'user', 'commit_sha', 'run_id', 'run_attempt'}
        for path in list((ROOT / 'sql').glob('*.sql')) + list((ROOT / 'tests').glob('*.sql')):
            text = path.read_text()
            self.assertNotRegex(text, r'\b(?:DEV_DB|QA_DB|PROD_DB)\.')
            for key in re.findall(r'<%\s*(\w+)\s*%>', text):
                self.assertIn(key, keys)
            self.assertEqual(text.count('$$') % 2, 0, str(path))

    def test_seeds_are_insert_only(self):
        text = (ROOT / 'sql/20_seed.sql').read_text()
        self.assertEqual(text.count('WHEN NOT MATCHED THEN INSERT'), 2)
        self.assertNotIn('WHEN MATCHED THEN', text)
        self.assertEqual(len(re.findall(r'^\s*\(1\d\d,', text, re.M)), 11)
        self.assertEqual(len(re.findall(r'^\s*\([1-4],', text, re.M)), 4)

    def test_deployment_order_and_checks(self):
        text = (ROOT / 'scripts/deploy.sh').read_text()
        ordered = ['sql/00_guard.sql', 'tests/isolation.sql', 'sql/10_raw_tables.sql', 'sql/20_seed.sql',
                   'sql/30_storage.sql', 'tests/snapshot_raw.sql', 'sql/40_clean_views.sql',
                   'sql/50_discount.sql', 'sql/60_process_orders.sql', 'sql/70_sales.sql',
                   'sql/80_task.sql', 'tests/assert_raw_preserved.sql', 'tests/assertions.sql',
                   'sql/90_record_release.sql']
        positions = [text.index(name) for name in ordered]
        self.assertEqual(positions, sorted(positions))
        for name in ordered:
            self.assertTrue((ROOT / name).is_file())
        self.assertIn('--enhanced-exit-codes', text)
        self.assertIn('set -euo pipefail', text)
        self.assertNotIn('setup.sql', text)

    def test_workflow_structure(self):
        workflows = {}
        for path in (ROOT / '.github/workflows').glob('*.yml'):
            doc = yaml.safe_load(path.read_text())
            workflows[path.stem] = doc
            self.assertIn('on', doc)
            self.assertNotIn('pull_request_target', doc['on'])
            for job in doc['jobs'].values():
                for step in job.get('steps', []):
                    if 'uses' in step:
                        self.assertRegex(step['uses'], r'@[0-9a-f]{40}$')
                        if step['uses'].startswith('actions/checkout'):
                            self.assertFalse(step['with']['persist-credentials'])
                            self.assertIn('ref', step['with'])
        release = workflows['promote']
        self.assertFalse(release['concurrency']['cancel-in-progress'])
        for target, dependency in [('dev', 'static'), ('qa', 'dev'), ('prod', 'qa')]:
            self.assertEqual(release['jobs'][target]['needs'], dependency)
            self.assertEqual(release['jobs'][target]['with']['commit_sha'], '${{ github.sha }}')
        self.assertIn('PROD_ENABLED', release['jobs']['prod']['if'])
        self.assertNotIn('environment', workflows['pr']['jobs']['sql'])
        self.assertIn('head.repo.full_name == github.repository', workflows['pr']['jobs']['sql']['if'])
        self.assertEqual(workflows['pr']['jobs']['validation-result']['needs'], ['static', 'sql'])

    def test_account_secret_wiring_and_missing_value(self):
        workflows = {path.stem: yaml.safe_load(path.read_text())
                     for path in (ROOT / '.github/workflows').glob('*.yml')}
        secret = '${{ secrets.SNOWFLAKE_ACCOUNT }}'
        self.assertTrue(workflows['deploy']['on']['workflow_call']['secrets']['SNOWFLAKE_ACCOUNT']['required'])
        for target in ['dev', 'qa', 'prod']:
            self.assertEqual(workflows['promote']['jobs'][target]['secrets'],
                             {'SNOWFLAKE_ACCOUNT': secret})
        for workflow, job_name in [('pr', 'sql'), ('deploy', 'deploy')]:
            job = workflows[workflow]['jobs'][job_name]
            self.assertEqual(job['env']['SNOWFLAKE_ACCOUNT'], secret)
            check = job['steps'][0]
            self.assertEqual(check['name'], 'Check account configuration')
            for value, expected in [('', 1), ('  \t', 1), ('EXAMPLE-ACCOUNT', 0)]:
                result = subprocess.run(['bash', '-c', check['run']],
                                        env=dict(os.environ, SNOWFLAKE_ACCOUNT=value),
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, expected)
                self.assertNotIn('EXAMPLE-ACCOUNT', result.stdout + result.stderr)
        for path in (ROOT / '.github/workflows').glob('*.yml'):
            self.assertNotIn('SFSENORTHAMERICA-DSHEMSI_AWS1', path.read_text())

    def test_exact_oidc_subjects_and_disabled_prod(self):
        text = (ROOT / 'setup.sql').read_text()
        prefix = 'repo:sfc-gh-dshemsi@216220113/snowflake-sql-cicd-demo@1426468222:'
        for suffix in ['pull_request', 'environment:dev', 'environment:qa', 'environment:prod']:
            self.assertIn(prefix + suffix, text)
        self.assertRegex(text, r'RETAIL_PROD_SVC\s+TYPE = SERVICE DISABLED = TRUE')

    def test_environment_gate_fail_closed(self):
        validate = load_script('check_environment').validate
        env = {'deployment_branch_policy': {'protected_branches': False, 'custom_branch_policies': True}}
        branches = {'branch_policies': [{'name': 'main', 'type': 'branch'}]}
        validate(env, branches, 'dev')
        with self.assertRaises(ValueError):
            validate(env, branches, 'prod')
        with self.assertRaises(ValueError):
            validate(env, {'branch_policies': [{'name': '*', 'type': 'branch'}]}, 'dev')
        env.update(can_admins_bypass=False, protection_rules=[{
            'type': 'required_reviewers', 'reviewers': [{'reviewer': {'id': 216220113}}]}])
        with self.assertRaises(ValueError):
            validate(env, branches, 'prod', [])
        validate(env, branches, 'prod', [{'state': 'approved', 'user': {'id': 216220113},
                                        'environments': [{'name': 'prod'}]}])


if __name__ == '__main__':
    unittest.main()
