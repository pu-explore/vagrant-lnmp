#!/usr/bin/env bash

if [[ -f /home/vagrant/.features/sources ]]; then
    echo "software source already changed."
    exit 0
fi

touch /home/vagrant/.features/sources
chown -Rf vagrant:vagrant /home/vagrant/.features

# shellcheck disable=SC2038
find /etc/apt -name 'sources.list' | xargs perl -pi -e "s|http://archive.ubuntu.com|$1|g"
# shellcheck disable=SC2038
find /etc/apt -name 'sources.list' | xargs perl -pi -e "s|http://security.ubuntu.com|$1|g"

apt-get update
