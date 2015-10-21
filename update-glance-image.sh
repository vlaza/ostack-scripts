#!/bin/bash
#
#
#
#

# Detecting if VM was rebooted in the last 3 minutes
touch /root/img-update.log
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
    time apt-get update -y
    time apt-get upgrade -y
    time aptitude safe-upgrade -y

    echo "Adding this script in crontab @reboot"
    echo "@reboot root /root/update-glance-image.sh >> /root/img-update.log" >> /etc/crontab

    echo "Rebooting for stage 2"
    reboot
else
    echo "Removing any older kernel than latest.."
    latest_kernel=$(uname -a | awk '{print $3}')
    latest_headers=$(uname -a | awk '{print $3}' | cut -d'-' -f1,2 )
    linux_image_2_remove=$(dpkg -l |grep linux-image | grep -v $latest_kernel | grep -v virtual | awk '{print $2}')
    linux_headers_2_remove=$(dpkg -l |grep linux-headers | grep -v $latest_headers | grep -v headers-generic | grep -v virtual | awk '{print $2}')
    set +e
    apt-get purge -y $linux_image_2_remove $linux_headers_2_remove
    set -e

    echo "Removing any packages that are no longer needed.."
    time apt-get autoremove -y

    echo "Cleaning apt-cache.."
    apt-get clean
    apt-get autoclean

    echo "Cleaning up logs.."
    pushd /var/log
    find . -type f -exec rm -fv {} \;
    popd

    echo "Removing this script from crontab.."
    sed -i "s'@reboot root /root/update-glance-image.sh >> /root/img-update.log'#@reboot root /root/update-glance-image.sh >> /root/img-update.log'g" /etc/crontab

    echo "Cleaning up history.."
    history -c # for root
    rm -f /home/ubuntu/.bash_history # for ubuntu user

    echo "Checking disk space after!"
    df

    echo "Zero-filling any free space.."
    cat /dev/zero > /root/zerofile; sync; rm -rfv /root/zerofile
    echo Zefo-fill done!"
fi
