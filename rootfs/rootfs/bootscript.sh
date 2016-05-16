#!/bin/sh

. /etc/rc.d/green_common

BOOT_DIR=/opt/boot

log_msg "== bootscript.sh: $(date) ===="

log_msg "configure sysctl"
/etc/rc.d/sysctl

log_msg "automount_zfs"
/etc/rc.d/automount_zfs

sleep 3
date
ip a >> $LOG_FILE

let count=0
while ( ! zfs_up ) && [ $count -lt 10 ]
do
  log_msg "cekam zfs_up"
  sleep 1
  let count=count+1
done

log_msg "if VirtualBox create green pool"
/usr/local/bin/vbox_create_pool.sh

/usr/local/bin/green_create_zfs.sh

let count=0
while ( ! mounted opt_boot ) && [ $count -lt 10 ]
do
   zfs_up && ( ! mounted opt_boot ) && ( mkdir -p $BOOT_DIR ; rm -r -f $BOOT_DIR/* ;  mount -o mountpoint=/opt/boot green/opt_boot )
   log_msg "waiting for mount zfs /opt/boot"
   sleep 1
   let count=count+1
done


log_msg "automount GREEN_volumes"
/etc/rc.d/automount

[ -d $BOOT_DIR/log ] || mkdir -p $BOOT_DIR/log
[ -f $BOOT_DIR/log/udhcp.log ] || rm $BOOT_DIR/log/udhcp.log

[ -d $BOOT_DIR/certs ] || mkdir -p $BOOT_DIR/certs
if [ -d /usr/local/etc/ssl/certs ]
then
  mv /usr/local/etc/ssl/certs/* $BOOT_DIR/certs/
  rm -r -f /usr/local/etc/ssl/certs
fi
ln -s $BOOT_DIR/certs /usr/local/etc/ssl/certs

log_msg "mount cgroups hierarchy"
/etc/rc.d/cgroupfs-mount
# see https://github.com/tianon/cgroupfs-mount

log_msg "import settings from profile (or unset them) $BOOT_DIR/profile"
test -f $BOOT_DIR/profile && . $BOOT_DIR/profile

log_msg "set the hostname"
/etc/rc.d/hostname

log_msg "sync the clock"
/etc/rc.d/ntpd &

log_msg "start cron"
/etc/rc.d/crond

log_msg "add docker:docker user"
if grep -q '^docker:' /etc/passwd; then
    # if we have the docker user, let's create the docker group
    /bin/addgroup -S docker
    # ... and add our docker user to it!
    /bin/addgroup docker docker

    #preload data from grenbox-cli
    #if [ -e "$BOOT_DIR/userdata.tar" ]; then
    #    tar xf $BOOT_DIR/userdata.tar -C /home/docker/ >> $LOG_FILE  2>&1
    #    rm -f 'greenbox, please format-me'
    #    chown -R docker:staff /home/docker
    #fi
fi

log_msg "init tiny.core applications (/usr/local/tce.installed)"
/etc/rc.d/tce-loader

log_msg "launch ACPID"
/etc/rc.d/acpid

log_msg "start openssh server"
/etc/rc.d/sshd

log_msg "Allow local bootsync.sh customisation"
if [ -e $BOOT_DIR/bootsync.sh ]; then
    $BOOT_DIR/bootsync.sh
    log_msg "after $BOOT_DIR/bootsync.sh"
fi

log_msg "virtualbox drivers"
/etc/rc.d/virtualbox

. /usr/local/bin/install_green_apps

log_msg "ldconfg after mounting apps"
/sbin/ldconfig -v >> $LOG_FILE 2>&1

log_msg "launch Docker"
/etc/rc.d/docker

log_msg "bootlocal.sh - allow local HD customisation"
if [ -e $BOOT_DIR/bootlocal.sh ]; then
    $BOOT_DIR/bootlocal.sh &
    log_msg "after $BOOT_DIR/bootlocal.sh"
fi

