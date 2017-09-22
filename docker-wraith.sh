#!/bin/bash

UID=`id -u`
sudo  docker run -v ~/.wraith/:/root/.wraith/ -it wraith "$@"
sudo chown -R $UID ~/.wraith
sudo chmod -R u+rw ~/.wraith
