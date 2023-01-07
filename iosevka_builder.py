import os.path
import requests
from rich.console import Console
import subprocess

# parameters
variants = ['niosevka', 'niosevka-fixed']
private_build_plan_repo_path = '/home/ning/data/iosevka/plans'
font_dist_path = f'{private_build_plan_repo_path}/dist'
version_file_path = f'{private_build_plan_repo_path}/dist/version'
telegram_bot_token = ''
telegram_chat_id = ''

# dependencies
console = Console()

def get_latest_version():
    r = requests.get('https://api.github.com/repos/be5invis/Iosevka/releases/latest')
    v = r.json()['tag_name']
    console.log('Latest "be5invis/Iosevka" release:', v)
    return v

def get_last_built_version():
    if not os.path.exists(version_file_path):
        v = 'Not found'
    else:
        with open (version_file_path, 'r') as f:
            v = ''.join(f.readlines())
    console.log('Last built version:', v)
    return v

def save_build_version(version):
    console.log(f'Saving built version {version} to {version_file_path}')
    with open(version_file_path, 'w') as f:
        f.write(version)

def execute_command(cmd, cwd=None):
    cmd_str = ' '.join(cmd)
    if cwd is None:
        console.log(cmd_str)
    else:
        console.log(cwd, cmd_str)
    r = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        console.log(r.returncode, r.stdout, r.stderr)
    return r.returncode, r.stdout, r.stderr

def send_message_via_telegram(msg):
    requests.get(f'https://api.telegram.org/{telegram_bot_token}/sendMessage?chat_id={telegram_chat_id}&text={msg}')

def send_artifacts_via_telegram(version):
    # TODO replace with Python native
    for variant in variants:
        src = variant
        dst = f'{variant}_{version}.zip'
        execute_command(['zip', '-r', dst, src], font_dist_path)
        execute_command(['curl', '-v', '-F', f'document=@{dst}', f'https://api.telegram.org/{telegram_bot_token}/sendDocument?chat_id={telegram_chat_id}'], font_dist_path)
        execute_command(['rm', '-rf', src], font_dist_path)
        execute_command(['rm', dst], font_dist_path)

# check if a new build is necessary
latest_version = get_latest_version()
last_built_version = get_last_built_version()

if last_built_version == latest_version:
    msg = f'No updates since last build. Latest: {latest_version}, last built: {last_built_version}, exiting.'
    console.log(msg)
    send_message_via_telegram(msg)
    exit(0)

# get prepared for building
r, _, _ = execute_command(['git', 'pull'], private_build_plan_repo_path)
if r != 0:
    console.log('Failed to pull private build plans.')
    exit(1)
# r, _, _ = execute_command(['docker', 'pull', 'avivace/iosevka-build'])
# if r != 0:
#     console.log('Failed to pull latest container image.')
#     exit(1)

# build fonts with container
r, _, _ = execute_command(['docker', 'run', '-v', f'{private_build_plan_repo_path}:/build', 'ning/iosevka-builder'] + [f'ttf::{variant}' for variant in variants])
if r != 0:
    console.log('Failed to build with docker.')
    exit(1)

# save build version
save_build_version(latest_version)

# send artifacts via Telegram Bot
send_artifacts_via_telegram(latest_version)
