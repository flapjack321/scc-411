#!/bin/bash

set -e -x

HAS_SSH_KEY=0

HADOOP_VERSION=2.8.5
HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
HADOOP_TARBALL=hadoop-$HADOOP_VERSION.tar.gz
HADOOP_USER=hadoop
HADOOP_DIRECTORY=/home/$HADOOP_USER/hadoop-$HADOOP_VERSION

HIVE_VERSION=2.3.8
HIVE_URL=http://apache.mirror.anlx.net/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz
HIVE_TARBALL=apache-hive-$HIVE_VERSION-bin.tar.gz
HIVE_DIRECTORY=/home/$HADOOP_USER/apache-hive-$HIVE_VERSION-bin

# Some helper functions
function copy-as-hadoop() {
    # Filename is stored in $1
    cp $(pwd)/hadoop/$1 $HADOOP_DIRECTORY/etc/hadoop/$1
    chown $HADOOP_USER:$HADOOP_USER $HADOOP_DIRECTORY/etc/hadoop/$1
    chmod 644 $HADOOP_DIRECTORY/etc/hadoop/$1
}
function copy-as-hive() {
    # Filename is stored in $1
    cp $(pwd)/hive/$1 $HIVE_DIRECTORY/conf/$1
    chown $HADOOP_USER:$HADOOP_USER $HIVE_DIRECTORY/conf/$1
    chmod 644 $HIVE_DIRECTORY/conf/$1
}


###
### System Admin
###

# delete the hadoop user
if id "$HADOOP_USER" &>/dev/null; then
    if [ -f "/home/$HADOOP_USER/.ssh/id_rsa" ]; then
        HAS_SSH_KEY=1
        # We need to copy out the keys
        cp /home/$HADOOP_USER/.ssh/id_rsa /tmp/hadoop_ssh_key
        cp /home/$HADOOP_USER/.ssh/id_rsa.pub /tmp/hadoop_ssh_key.pub
        # Copy out authorized_keys so ssh-copy-id doesn't need to be rerun on nodes
        cp /home/$HADOOP_USER/.ssh/authorized_keys /tmp/hadoop_authorized_keys
    fi

    deluser $HADOOP_USER
    rm -rf /home/$HADOOP_USER
fi


# create a new hadoop user
useradd -m \
    -p "$(python3 -c 'import crypt; print(crypt.crypt("hadoop"))')" \
    -s /bin/bash \
    $HADOOP_USER

###
### Install hadoop
###

# generate SSH keys
if [ "$HAS_SSH_KEY" -eq "0" ]; then
    # No ssh key present so generate one
    su $HADOOP_USER <<EOF
set -e -x
mkdir ~/.ssh
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ''
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
EOF
else
    # SSH was present so copy from tmp
    mkdir /home/$HADOOP_USER/.ssh
    cp /tmp/hadoop_ssh_key /home/$HADOOP_USER/.ssh/id_rsa
    chmod 600 /home/$HADOOP_USER/.ssh/id_rsa
    cp /tmp/hadoop_ssh_key.pub /home/$HADOOP_USER/.ssh/id_rsa.pub
    chmod 644 /home/$HADOOP_USER/.ssh/id_rsa.pub
    cp /tmp/hadoop_authorized_keys /home/$HADOOP_USER/.ssh/authorized_keys
    chmod 664 /home/$HADOOP_USER/.ssh/authorized_keys

    chown -R $HADOOP_USER:$HADOOP_USER /home/$HADOOP_USER/.ssh
fi


# download hadoop
su $HADOOP_USER <<EOF
set -e -x
mkdir ~/downloads
wget --quiet -O ~/downloads/$HADOOP_TARBALL $HADOOP_URL
tar -zxf ~/downloads/$HADOOP_TARBALL -C ~/


# add env variables
echo "export HADOOP_HOME=$HADOOP_DIRECTORY" >> ~/.bashrc
echo "export HADOOP_INSTALL=$HADOOP_DIRECTORY" >> ~/.bashrc
echo "export HADOOP_COMMON_HOME=$HADOOP_DIRECTORY" >> ~/.bashrc
echo "export HADOOP_MAPRED_HOME=$HADOOP_DIRECTORY" >> ~/.bashrc
echo "export HADOOP_HDFS_HOME=$HADOOP_DIRECTORY" >> ~/.bashrc
echo "export HADOOP_COMMON_LIB_NATIVE=$HADOOP_DIRECTORY/lib/native" >> ~/.bashrc
echo "export YARN_HOME=$HADOOP_DIRECTORY" >> ~/.bashrc
echo "export HADOOP_OPTS=\"-Djava.library.path=$HADOOP_DIRECTORY/lib/native\"" >> ~/.bashrc
echo "export PATH=$PATH:$HADOOP_DIRECTORY/sbin:$HADOOP_DIRECTORY/bin" >> ~/.bashrc

# create extra directories
mkdir ~/hadooptempdata
mkdir ~/hdfs
mkdir ~/hdfs/namenode
mkdir ~/hdfs/datanode

EOF

# copy hadoop configuration files in place
# note: not perfect as versions etc. are hard coded in these files
copy-as-hadoop hadoop-env.sh
copy-as-hadoop core-site.xml
copy-as-hadoop hdfs-site.xml
copy-as-hadoop mapred-site.xml
copy-as-hadoop yarn-site.xml

# format the hadoop namenode
su $HADOOP_USER <<EOF
set -e -x
PATH=$PATH:$HADOOP_DIRECTORY/bin hdfs namenode -format 1> /dev/null 2>&1
echo "Exit code $?"
EOF

echo "Hadoop has been successfully setup. Run 'start-dfs.sh' and 'start-yarn.sh'"


su $HADOOP_USER <<EOF
set -e -x
curl -fsSL https://data.cdc.gov/api/views/g4ie-h725/rows.csv\?accessType\=DOWNLOAD > ~/downloads/chronic_diseases.csv
EOF


###
### Begin Hive install
###
su $HADOOP_USER <<EOF
set -e -x
wget --quiet -O ~/downloads/$HIVE_TARBALL $HIVE_URL
tar -zxf ~/downloads/$HIVE_TARBALL -C ~/

echo "export HIVE_HOME=$HIVE_DIRECTORY" >> ~/.bashrc
echo "export HIVE_CONF_DIR=/home/$HADOOP_USER/apache-hive-$HIVE_VERSION/conf" >> ~/.bashrc
echo "export PATH=$PATH:$HADOOP_DIRECTORY/sbin:$HADOOP_DIRECTORY/bin:$HIVE_DIRECTORY/bin" >> ~/.bashrc
EOF

copy-as-hive hive-env.sh
copy-as-hive hive-site.xml

su $HADOOP_USER <<EOF
set -e -x
cd $HIVE_DIRECTORY
bin/schematool -initSchema -dbType derby 1> /dev/null 2>&1
echo "Schema tools return code $?"
EOF
