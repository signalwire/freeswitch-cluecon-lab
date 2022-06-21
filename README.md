# FreeSWITCH Workshop

This is a lab-style image for the FreeSWITCH workshop. It is built around Docker for ease of use.

The configuration folder is mounted to the Docker container for ease of access.

## Building

You need a SignalWire account to download the packages. It is free to sign up, and you can find instructions [here](https://freeswitch.org/confluence/display/FREESWITCH/HOWTO+Create+a+SignalWire+Personal+Access+Token).

Add that to your `.env` file.

## Starting FreeSWITCH

Install Docker and Docker Compose, copy `env.example` to `.env` and set a password.

After doing that, run `docker-compose build` followed by `docker-compose up -d`.

Wait for FreeSWITCH to spin up, then run `docker-compose exec freeswitch bash` to access the container shell. The familiar `fs_cli` command will be available from there.

### Notes

The Docker images are meant to be used on a non-firewalled machine running Docker on Linux.
