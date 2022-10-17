#!/bin/bash -e

install -m 644 files/matrix-synapse.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/setup-script.sh "${ROOTFS_DIR}/home/pi/"
install -m 644 files/gen-matrix-config.sh "${ROOTFS_DIR}/home/pi/"
install -m 644 files/configure-postgres.sh "${ROOTFS_DIR}/home/pi/"

on_chroot << EOF

mkdir -p /home/pi/install

EOF

install -m 644 files/element-v1.10.12.tar.gz "${ROOTFS_DIR}/home/pi/install/"


on_chroot << EOF

ln -s /etc/systemd/system/matrix-synapse.service /etc/systemd/system/multi-user.target.wants/matrix-synapse.service

chmod +x /home/pi/setup-script.sh
chmod +x /home/pi/gen-matrix-config.sh
chmod +x /home/pi/configure-postgres.sh

sed -i '\$asudo ./setup-script.sh' /home/pi/.bashrc

cd /usr/lib/systemd/system
sed -i '/^After=/c\After=network-online.target\nWants=network-online.target' coturn.service


EOF

# cd /lib/systemd/system
# sed -i '/ExecStart=/c\ExecStart=-\/sbin\/agetty --noclear -a pi %I \$TERM' getty@.service
