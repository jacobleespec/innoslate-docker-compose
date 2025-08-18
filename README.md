# Innoslate Docker Installer

An installer for **Innoslate** using Docker Compose. It uses the following images:

- [Innoslate](https://hub.docker.com/r/innoslate/innoslate)
- [Nginx](https://hub.docker.com/_/nginx)
- [Postgres](https://hub.docker.com/_/postgres)

---

## Prerequisites

- Docker and Docker Compose installed
- Bash shell (macOS/Linux; on Windows use WSL or Git Bash)

---

## Installation

1. Change to the directory containing `install.sh`:

       cd path/to/installer

2. (macOS/Linux) Make the script executable:

       chmod +x ./install.sh

3. Run the installer:

       ./install.sh

---

## Setup

If a step is not specified, you can use the defaults or provide your own values.

### License

Provide one of the following license types:

- **Legacy license**
- **Docker license**

### Database

#### Using an External Database
Supply your own connection details during setup.

#### Using the Included Postgres Container
Use the following values:

- **Database Type:** `PostgreSQL`
- **Database Host:** `postgres`
- **Database Port:** *(leave empty)*
- **Database Name:** the name you provided to the Docker Compose installer
- **Database Username:** `postgres`
- **Database Password:** the password you provided to the Docker Compose installer

---

## Filesystem

- **File Storage Path:** `/usr/local/innoslate/filestore`
