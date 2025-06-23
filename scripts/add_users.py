import csv
import subprocess
import sys
from pathlib import Path

SSH_KEY = "/home/jstet/.ssh/hnh25"
SSH_HOST = "correlaid@hnh25.netbird.cloud"

def execute_ssh_command(username, email):
    """Execute SSH command to create user via Docker"""
    python_script = f"""from dribdat.mailer import user_activation

user = User("{username}","{email}")
user_activation(user)
print(f"User {username} activated successfully")"""

    docker_command = f"cd dribdat && echo '{python_script}' | docker compose exec -T dribdat-web ./manage.py shell"
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
        stderr_lines = result.stderr.strip().split('\n')
        stderr_lines = stderr_lines[3:-1]
        stderr_lines = [line for line in stderr_lines if line.strip()]
        stderr = '\n'.join(stderr_lines)
        return result.stdout, stderr
    except subprocess.TimeoutExpired:
        return "Error: SSH command timed out"
    except Exception as e:
        return f"Error: {str(e)}"

def main():
    csv_file = sys.argv[1]

    if not Path(csv_file).exists():
        print(f"Error: CSV file '{csv_file}' not found")
        sys.exit(1)

    total = 0
    success = 0
    failed = 0

    with open(csv_file, 'r', newline='', encoding='utf-8') as file:
        csv_reader = csv.DictReader(file)

        for row in csv_reader:
            username = row['username'].strip().strip('"')
            email = row['email'].strip().strip('"')

            total += 1
            print(f"Processing user {total}: {username} ({email})")
        
            _, stderr = execute_ssh_command(username, email)

            if stderr != "":
                print("\n",stderr,"\n")
                print(f"Failed for {email}")
                failed += 1
            else:
                success += 1

    print()
    print("=== Summary ===")
    print(f"Total processed: {total}")
    print(f"Successfully created: {success}")
    print(f"Failed: {failed}")

if __name__ == "__main__":
    main()
