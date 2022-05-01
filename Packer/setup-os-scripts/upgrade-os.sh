#!/bin/bash

sudo ros os upgrade -f --no-reboot

sudo dd if=/dev/zero of=/borrar.img bs=1M
sudo rm -fr /borrar.img