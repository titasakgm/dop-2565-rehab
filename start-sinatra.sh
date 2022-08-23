#!/bin/bash

cd /opt/SINATRA

docker run --name sinatra \
-u 1000:1000 \
-v ${PWD}:/opt/SINATRA \
--net host \
-d sinatra:drtoon tail -f /dev/null

#-d ruby:3 tail -f /dev/null

