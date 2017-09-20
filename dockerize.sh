#!/bin/bash

IT=`docker images -q wraith`
docker rmi -f "$IT"
docker build -t wraith .
