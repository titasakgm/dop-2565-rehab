#!/bin/bash

cd /opt/SINATRA
/usr/local/bin/ruby ./test-upload.rb > /dev/null
tail -f /dev/null

