Innoslate installer that uses Docker Compose, and the following images:
* [Innoslate](https://hub.docker.com/r/innoslate/innoslate)
* [Nginx](https://hub.docker.com/_/nginx)
* [Postgres](https://hub.docker.com/_/postgres)

# Innoslate Docker Installer
1. `cd` into the directory with `install.sh`
2. If on MacOS/Linux, `chmod +x ./install.sh`
3. Run `./install.sh`

# Innoslate Setup
If a step isn't specified, the default values can be used or the user can supply their own configuration.

## License
License given should be either a **legacy license**, or a **docker license**.

## Database
If using an external database, you will need to supply your own information.

If using the included postgres container:

**Database Type:** `PostgreSQL`

**Database Host:** `postgres`

**Database Port:** *empty*

**Database Name:** Use name that you supplied the docker compose installer

**Database Username:** `postgres`

**Database Password:** Use password that you supplied the docker compose installer

## Filesystem Information
**File Storage Path:** `/usr/local/innoslate/filestore`
