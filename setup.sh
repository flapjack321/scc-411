#!/bin/bash

HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-2.8.5/hadoop-2.8.5.tar.gz
HADOOP_TARBALL=hadoop-2.8.2.tar.gz
HADOOP_USER=hadoop
HADOOP_HOME_DIR=/home/$HADOOP_HOME
HADOOP_DIRECTORY=/home/hadoop/hadoop-2.8.5


set -e

# delete the hadoop user
if id "$HADOOP_USER" &>/dev/null; then
    echo "**** deleting user $HADOOP_USER ****"
    deluser $HADOOP_USER
    rm -rf /home/hadoop
fi


# create a new hadoop user
useradd -m \
    -p $(python3 -c 'import crypt; print(crypt.crypt("hadoop"))') \
    -s /bin/bash \
    hadoop


# generate SSH keys
su $HADOOP_USER <<EOF
mkdir ~/.ssh
ssh-keygen -t rsa -f /home/hadoop/.ssh/id_rsa -q -N ''"
cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys"

# download hadoop
mkdir ~/downloads
wget -O ~/downloads/$HADOOP_TARBALL $HADOOP_URL
tar -zxvf ~/downloads/$HADOOP_TARBALL -C $HADOOP_HOME_DIR


# add env variables
echo "export HADOOP_HOME=$HADOOP_HOME_DIR/hadoop-2.8.5" >> ~/.bashrc

EOF
