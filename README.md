
## Info Mail

You will receive an email to the address you provided when you registered for the hackathon. This email will be sent from mail@correlaid.de and will contain a link to verify your account. To avoid posting information that you do not want to make public, your public username has been set to a random string of characters. You can update your username in your [profile](https://hack.correlaid.org/user/profile). While you can always log in with your e-mail address only, you can also set a password there.


## Create Project
This challenge is awaiting approval from an organizer. 

### Create manual backup

docker exec dribdat-db su - postgres -c "WALG_DELTA_MAX_STEPS=0 envdir /etc/wal-g/env /usr/local/bin/wal-g backup-push /var/lib/postgresql/data"

### Point in time recovery

```
docker compose down --volumes
docker volume rm pgdata

# Fetch backup 
docker run --rm \
  --env-file .env \
  --user postgres \
  -v pgdata:/var/lib/postgresql/data \
  lafayettegabe/wald:latest \
  envdir /etc/wal-g/env /usr/local/bin/wal-g backup-fetch /var/lib/postgresql/data LATEST

# Configure recovery
docker run --rm \
  -v pgdata:/var/lib/postgresql/data \
  lafayettegabe/wald:latest \
  bash -c "
touch /var/lib/postgresql/data/recovery.signal
cat >> /var/lib/postgresql/data/postgresql.auto.conf << 'EOF'
restore_command = 'envdir /etc/wal-g/env /usr/local/bin/wal-g wal-fetch %f %p'
EOF
"
docker compose up -d
```