# ClueCon TGI 2021 Freeswitch Workshop

This is a lab-style image for the ClueCon TGI 2021 FreeSWITCh workshop. It is built around Docker for ease of use.

The configuration folder is mounted to the Docker container for ease of access.

## Starting FreeSWITCH

Install Docker and Docker Compose, copy `env.example` to `.env` and set a password.

After doing that, run `docker-compose build` followed by `docker-compose up -d`.

Wait for FreeSWITCH to spin up, then run `docker-compose exec freeswitch bash` to access the container shell. The familiar `fs_cli` command will be available from there.

### Notes

The Docker images are menat to be used on a non-firewalled machine running Docker on Linux.
