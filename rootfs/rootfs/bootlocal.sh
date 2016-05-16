#!/bin/sh

ls -1 /opt/boot/init.d/ | xargs -I %  /opt/boot/init.d/%
