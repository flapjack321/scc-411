#!/bin/bash

set -x -e

HOSTNAME=$(hostname)

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

function copy-bashrc() {
    cp $(pwd)/bashrc ~/.bashrc
    chmod 644 ~/.bashrc
}

###
### Admin Tasks
### It is assumed the user already has all the SSH keys added and has their own
### generated SSH key
###
echo "Killing existing hadoop/hive processes"
if jps 1>/dev/null 2>&1 ; then 
    # jps is an installed command
    # kill everything
    JOBS=$(jps | grep -v "Jps" | cut -d' ' -f1)
    if [ ! -z "$JOBS" ]; then
        kill -9 $JOBS
    fi
fi

###
### Install Hadoop
###
mkdir -p ~/downloads
wget --quiet -O ~/downloads/$HADOOP_TARBALL $HADOOP_URL
tar -zxf ~/downloads/$HADOOP_TARBALL -C ~/

# remove and recreate directories
rm -rf ~/hadooptempdata
mkdir ~/hadooptempdata

rm -rf ~/hdfs
mkdir ~/hdfs
mkdir ~/hdfs/namenode
mkdir ~/hdfs/datanode

# copy hadoop configuration files in place
# note: not perfect as versions etc. are hard coded in these files
copy-as-hadoop hadoop-env.sh
copy-as-hadoop core-site.xml
copy-as-hadoop hdfs-site.xml
copy-as-hadoop mapred-site.xml
copy-as-hadoop yarn-site.xml

###
### Edit master and slaves files
### This only needs to be done on the master node, where all other
### nodes will be controlled from.
###
if [ "$HOSTNAME" = "scc-411-04" ]; then
    echo "scc-411-04" > $HADOOP_DIRECTORY/etc/hadoop/masters
    echo "scc-411-10" > $HADOOP_DIRECTORY/etc/hadoop/slaves
    echo "scc-411-11" >> $HADOOP_DIRECTORY/etc/hadoop/slaves
    echo "scc-411-19" >> $HADOOP_DIRECTORY/etc/hadoop/slaves
    echo "scc-411-48" >> $HADOOP_DIRECTORY/etc/hadoop/slaves
    echo "scc-411-55" >> $HADOOP_DIRECTORY/etc/hadoop/slaves
    echo "scc-411-63" >> $HADOOP_DIRECTORY/etc/hadoop/slaves
fi

###
### Format HDFS namenode
###
$HADOOP_DIRECTORY/bin/hdfs namenode -format 1> /dev/null 2>&1
echo "Formatting HDFS namenode exit code $?"

echo "Hadoop has been successfully setup. Run 'start-dfs.sh' and 'start-yarn.sh'"

###
### Begin Hive install
###
wget --quiet -O ~/downloads/$HIVE_TARBALL $HIVE_URL
rm -rf $HIVE_DIRECTORY
tar -zxf ~/downloads/$HIVE_TARBALL -C ~/

copy-as-hive hive-env.sh
copy-as-hive hive-site.xml

###
### Copy configured bashrc
###
copy-bashrc
source ~/.bashrc

###
### Setup Derby
###
cd $HIVE_DIRECTORY
bin/schematool -initSchema -dbType derby 1> /dev/null 2>&1
echo "Schema tools return code $?"
