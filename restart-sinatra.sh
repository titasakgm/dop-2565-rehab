#!/bin/bash

docker exec -t sinatra pkill ruby
docker exec -t sinatra cd /opt/SINATRA && ./test-upload.rb &

