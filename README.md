
## Infrastrucure as Code Repository for [Hackbase](https://hackbase.correlaid.org/) - The Hackathon Challenge board of the [Hack and Harvest 2025](https://www.hackandharvest.farm/)

- Hackbase is a self-hosted [dribdat](https://dribdat.cc/) instance. 
- Find a user guide for dribdat [here](https://dribdat.cc/usage.html)

## User Information

### How to get access

Self-Registration is deactivated. Instead you will receive an email to the address you provided when you registered for the hackathon. This email will be sent from `mail@correlaid.de` and will contain a link to verify your account. 

### Updating your profile

To avoid posting information that you do not want to make public, your public username has been set to a random string of characters. You can update your username in your [profile](https://hack.correlaid.org/user/profile). While you can always log in with your e-mail address only, you can also set a password there. Remember, however, that all information apart from your E-Mail and password will be **public**, meaning viewable without having to log in. We are currently not 100% clean on OPSEC.

Please feel free to update your profile with the information you are comfortable with sharing, such as your work experience, as that may be relevant to other participants.


### Create a project

Should you decide to hand in a project idea/pitch, go to the hackathon event and click on "Post a challenge". Dribdat allows syncing external documents such as READMEs with your project. Maybe you already know that you are going to code in your project? In that case syncing with your README will save you some work. [Here](https://dribdat.cc/sync.html) is more info on this. However you can also continue without importing a README at the bottom of the page. In that case, at least provide a title for your project. Like user profiles, projects are **public**!

Ignore the message you will be shown saying "This project is waiting for approval by an organizer", because it is a lie.

### Join a project

In the event view, you can see an overview of projects. See something interesting? Why not join this project?

### Leveling up

The idea of dribdat is that you advance through stages while your project progresses. This hackathon has [3 stages](https://github.com/CorrelAid/hnh25_iac/blob/main/ansible/files/stages.yml) configured. To advance to the first stage, called pitch, your project needs a short summary and pitch. After you have edited your project to meet these requirements, post an update in the project feed and you will level up. The next stage can be reached after at least one person has joined your team. Again, post an update and you will advance to the next stage.

When the hackathon starts, the admins will disallow project creation and hide non-active projects that have not advanced to the stage conveniently called "Project". 

During the hackathon, it would be interesting for other participants (and the jurors :wink:) to see what you are working on, so consider posting updates if you feel like it.

At the end of the hackathon, all projects should advance to the "Presentation" stage. This can be done by uploading a PDF or providing a link to such in the presentation field.


## Internal Technical Stuff

### Create manual backup
```
docker exec dribdat-db su - postgres -c "WALG_DELTA_MAX_STEPS=0 envdir /etc/wal-g/env /usr/local/bin/wal-g backup-push /var/lib/postgresql/data"
```
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