#!/bin/bash
#
# 2015 (c) Victor Laza @ CloudBase Solutions
# 
# This script takes the standard CloudBase Devstack Glance image and updates it
# and optimizes disk space at the end

# Detecting if VM was rebooted in the last 3 minutes
reboot_time=$(uptime | awk '{print $3}')
if [ $reboot_time -ge 3 ] 
then
    echo "Checking disk space before!"
    df

    echo "Updating openstack repositories.."
    pushd /opt/stack
    time for i in `ls`; do cd $i ; git pull ; cd .. ; done
    popd

    echo "Updating devstack repository.."
    pushd /home/ubuntu/devstack
    time git pull
    popd

    echo "Updating packages.."
    time sudo apt-get update -y
    time sudo apt-get upgrade -y
    time sudo aptitude safe-upgrade -y

    echo "Adding this script in crontab @reboot"
    echo "@reboot root /root/update-glance-image.sh" | sudo tee -a /etc/crontab

    echo "Rebooting for stage 2"
    reboot
else
    echo "Removing any older kernel than latest.."
    latest_kernel=$(uname -a | awk '{print $3}')
    latest_headers=$(uname -a | awk '{print $3}' | cut -d'-' -f1,2 )
    linux_image_2_remove=$(dpkg -l |grep linux-image | grep -v $latest_kernel | grep -v virtual | awk '{print $2}')
    linux_headers_2_remove=$(dpkg -l |grep linux-headers | grep -v $latest_headers | grep -v headers-generic | grep -v virtual | awk '{print $2}')
    set +e
    sudo apt-get purge -y $linux_image_2_remove $linux_headers_2_remove
    set -e

    echo "Removing any packages that are no longer needed.."
    time sudo apt-get autoremove -y

    echo "Cleaning apt-cache.."
    sudo apt-get clean
    sudo apt-get autoclean

    echo "Cleaning up logs.."
    pushd /var/log
    find . -type f -exec sudo rm -fv {} \;
    popd

    echo "Removing this script from crontab.."
    sudo sed -i "s'@reboot root /root/update-glance-image.sh'#'g" /etc/crontab

    echo "Cleaning up history.."
    sudo rm -f /root/.bash_history # for root
    sudo rm -f /home/ubuntu/.bash_history # for ubuntu user

    echo "Checking disk space after!"
    df

    echo "Zero-filling any free space must be done manually by running:"
    echo "cat /dev/zero > /root/zerofile; sync; rm -rf /root/zerofile"
    echo "Don't forget also to: history -c && shutdown -h now"
    echo "After instance is stopped: nova image-create <instance name or uuid> <name of new image>"
fi
