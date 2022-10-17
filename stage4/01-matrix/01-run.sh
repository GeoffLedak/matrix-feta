#!/bin/bash -e

on_chroot << EOF

cd /home/pi

pip3 install bcrypt==3.2.2

pip3 install virtualenv
update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1

su pi
mkdir matrix
cd matrix
mkdir synapse
virtualenv ~/matrix/synapse/env
source ~/matrix/synapse/env/bin/activate
pip3 install --upgrade pip virtualenv six packaging appdirs setuptools
pip3 install bcrypt==3.2.2
pip3 install matrix-synapse==1.61
/home/pi/matrix/synapse/env/bin/pip install "matrix-synapse[postgres]==1.61"
/home/pi/matrix/synapse/env/bin/pip install psycopg2==2.9.1

exit

EOF
