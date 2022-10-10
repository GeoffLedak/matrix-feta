#!/bin/bash
. /home/pi/matrix/synapse/env/bin/activate

cd /home/pi/matrix
python -m synapse.app.homeserver --server-name $1 --config-path homeserver.yaml --generate-config --report-stats=yes
