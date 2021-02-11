#!/bin/bash

HADOOP_VERSION=2.8.5
HADOOP_URL=https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
HADOOP_TARBALL=hadoop-$HADOOP_VERSION.tar.gz
HADOOP_USER=hadoop
HADOOP_DIRECTORY=/home/$HADOOP_USER/hadoop-$HADOOP_VERSION


set -e -x

# delete the hadoop user
if id "$HADOOP_USER" &>/dev/null; then
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
set -e -x
mkdir ~/.ssh
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ''
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys

# download hadoop
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
cp $(pwd)/hadoop/hadoop-env.sh /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/hadoop-env.sh
chmod 644 /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/hadoop-env.sh
chown hadoop:hadoop /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/hadoop-env.sh

cp $(pwd)/hadoop/core-site.xml /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/core-site.xml
chmod 644 /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/core-site.xml
chown hadoop:hadoop /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/core-site.xml

cp $(pwd)/hadoop/hdfs-site.xml /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/hdfs-site.xml
chmod 644 /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/hdfs-site.xml
chown hadoop:hadoop /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/hdfs-site.xml

cp $(pwd)/hadoop/mapred-site.xml /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/mapred-site.xml
chmod 644 /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/mapred-site.xml
chown hadoop:hadoop /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/mapred-site.xml

cp $(pwd)/hadoop/yarn-site.xml /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/yarn-site.xml
chmod 644 /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/yarn-site.xml
chown hadoop:hadoop /home/hadoop/hadoop-$HADOOP_VERSION/etc/hadoop/yarn-site.xml

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
