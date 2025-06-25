import csv
import subprocess
import sys
from pathlib import Path

SSH_KEY = "/home/jstet/.ssh/hnh25"
SSH_HOST = "correlaid@hnh25.netbird.cloud"
cwd = "dribdat"
container_name = "dribdat-web"

def execute_ssh_command(command_description, python_script):
    """Execute SSH command via Docker"""
    docker_command = f"cd {cwd} && echo '{python_script}' | docker compose exec -T {container_name} ./manage.py shell"
    ssh_command = [
        "ssh",
        "-i", SSH_KEY,
        SSH_HOST,
        docker_command
    ]

    try:
        result = subprocess.run(
            ssh_command,
            capture_output=True,
            text=True,
            timeout=30 
        )
        print(result.stderr)
        print(result.stdout)
        stderr_lines = result.stderr.strip().split('\n')
        stderr_lines = stderr_lines[3:-1]
        stderr_lines = [line for line in stderr_lines if line.strip()]
        stderr = '\n'.join(stderr_lines)
        return result.stdout.strip(), stderr
    except subprocess.TimeoutExpired:
        return "Error: SSH command timed out", ""
    except Exception as e:
        return f"Error: {str(e)}", ""

def delete_user_by_email(email):
    print(email)
    python_script = f"""user = User.query.filter_by(email="{email}").first()
user.delete()
"""
    return execute_ssh_command("Delete user", python_script)

def create_and_activate_user(username, email):
    python_script = f"""
from dribdat.mailer import user_activation

# Check if user already exists
existing_user = User.query.filter_by(email="{email}").first()
if existing_user:
    print(f"User with email {email} already exists")
else:
    user = User("{username}", "{email}")
    user_activation(user)
"""
    return execute_ssh_command("Create and activate user", python_script)

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <csv_file>")
        print("CSV file should have columns: username,email")
        sys.exit(1)

    csv_file = sys.argv[1]

    if not Path(csv_file).exists():
        print(f"Error: CSV file '{csv_file}' not found")
        sys.exit(1)

    total = 0
    deleted_success = 0
    deleted_failed = 0
    created_success = 0
    created_failed = 0

    with open(csv_file, 'r', newline='', encoding='utf-8') as file:
        csv_reader = csv.DictReader(file)

        for row in csv_reader:
            username = row['username'].strip().strip('"')
            email = row['email'].strip().strip('"')

            total += 1
            print(f"\n=== Processing user {total}: {username} ({email}) ===")

            # delete existing user
            print("Step 1: Deleting existing user...")
            stdout, stderr = delete_user_by_email(email)

            if stderr:
                print(f"Delete error: {stderr}")
                deleted_failed += 1
                print("Skipping creation due to deletion failure")
                created_failed += 1
                continue
            else:
                print(f"Delete result: {stdout}")
                deleted_success += 1

            # create and activate new user
            print("Step 2: Creating and activating new user...")
            stdout, stderr = create_and_activate_user(username, email)

            if stderr:
                print(f"Create error: {stderr}")
                created_failed += 1
            else:
                print(f"Create result: {stdout}")
                created_success += 1

    print("\n" + "="*50)
    print("=== FINAL SUMMARY ===")
    print(f"Total processed: {total}")
    print(f"Users deleted successfully: {deleted_success}")
    print(f"Users deletion failed: {deleted_failed}")
    print(f"Users created successfully: {created_success}")
    print(f"Users creation failed: {created_failed}")
    print("="*50)

if __name__ == "__main__":
    main()
