#!/usr/bin/env bash  

# Script  to do intial set up
setup() 
{
	# export DEBIAN_FRONTEND=noninteractive command is used to tell shell, turn installation mode to non interactive    
	export 	DEBIAN_FRONTEND=noninteractive 

		INIT_DIR="/etc/init.d"

		DOCKER_DIR="/usr/local/docker"		
		DOCKER_URL="http://mirrors.sonic.net/apache/docker/common/docker-2.6.0"
		DOCKER_PKG="docker-2.6.0.tar.gz"
	
		
	# Set auto selection of agreement for Sun Java
	echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections  
	echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
}


# Script to install OpenSSH
install_ssh() 
{
	apt-get install openssh-server -y
	/etc/init.d/ssh status  
	/etc/init.d/ssh start

	ssh-keyscan -H localhost > ~/.ssh/known_hosts 
	y|ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa
	cat ~/.ssh/id_dsa.pub > ~/.ssh/authorized_keys  
	ssh-add
}


#script to Install docker
install_docker() 
{
	echo "Downloading Docker. This will take several minutes...."

	cd /usr/local

	wget -cq ${DOCKER_URL}/${DOCKER_PKG}
	if [ $? -ne 0 ]; then
		echo "Failed to download docker"
		return 1
	fi

	tar xvzf docker-2.6.0.tar.gz
	if [ $? -ne 0 ]; then
		echo "Unable to install docker"
		return 1
	fi
	
	# -----------------------------------------------------
	
	# Install Docker on Ubuntu 14.04.4 x64
	# Ref https://docs.docker.com/engine/installation/linux/ubuntulinux/
	# No interactive for now.
	export DEBIAN_FRONTEND=noninteractive
	# Update your APT package index.
	sudo apt-get -y update
	# Update package information, ensure that APT works with the https method, and that CA certificates are installed.
	sudo apt-get install apt-transport-https ca-certificates
	# Add the new GPG key.
	sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
	# Add docker.list 
	sudo echo "deb https://apt.dockerproject.org/repo ubuntu-trusty experimental" > /etc/apt/sources.list.d/docker.list
	# Update your APT package index.
	sudo apt-get -y update
	# Purge the old repo if it exists.
	sudo apt-get purge lxc-docker
	# Verify that APT is pulling from the right repository.
	sudo apt-cache policy docker-engine
	# Install the recommended package.
	sudo apt-get -y install linux-image-extra-$(uname -r)
	# Ubuntu 14.04 or 12.04, apparmor is required.
	sudo apt-get -y install apparmor
	# Install Docker.
	sudo apt-get -y install docker-engine
	# Start the docker daemon.
	sudo service docker start
	# Validate docker version
	docker -v

	#------------------------------------------------------------------

	cd ${DOCKER_DIR}
	mv -v ../docker-2.6.0/* ${DOCKER_DIR}

	touch ${DOCKER_DIR}/.downloaded

	# Setting up the Confiuration Files		
	configure_bashrc
	configure__files
}


configure_bashrc()
{
	echo "Updating Bashrc for export Path etc...."  

cat >> ~/.bashrc << EOF
export JAVA_HOME=/usr/lib/jvm/java-7-oracle/jre
export DOCKER_HOME=/usr/local/docker
export DOCKER_MAPRED_HOME=/usr/local/docker
export DOCKER_COMMON_HOME=/usr/local/docker
export DOCKER_HDFS_HOME=/usr/local/docker
export YARN_HOME=/usr/local/docker
export DOCKER_COMMON_LIB_NATIVE_DIR=/usr/local/docker/lib/native
export DOCKER_OPTS="-Djava.library.path=/usr/local/docker/lib"
export PATH="${PATH}:/usr/local/docker/sbin:/usr/local/docker/bin:/usr/lib/jvm/java-7-oracle/jre/bin"
EOF

	cat ~/.bashrc
	source ~/.bashrc  
}

configure_docker_files()
{
	echo "Updating docker-env.sh...."
cat >> /usr/local/docker/etc/docker/docker-env.sh << EOF
export JAVA_HOME=/usr/lib/jvm/java-7-oracle/jre
export DOCKER_OPTS="-Djava.net.preferIPv4Stack=true"
EOF
	cd /usr/local/docker/etc/docker
	
	echo "Updating core-site.xml...."
cat > /usr/local/docker/etc/docker/core-site.xml << EOF
<configuration>
<property>
<name>fs.default.name</name>
<value>hdfs://localhost:9000</value> 
</property>
</configuration>
EOF

	cp mapred-site.xml.template mapred-site.xml
	echo "Updating mapred-site.xml...."
cat > /usr/local/docker/etc/docker/mapred-site.xml << EOF
<configuration>
<property>
<name>mapreduce.framework.name</name>
<value>yarn</value>
</property>
</configuration>
EOF

	echo "Updating yarn-site.xml...."
cat > /usr/local/docker/etc/docker/yarn-site.xml << EOF
<configuration>
<property>
<name>yarn.nodemanager.aux-services</name>
<value>mapreduce_shuffle</value>
</property>
</configuration>
EOF

	echo "Updating hdfs-site.xml...."
cat > /usr/local/docker/etc/docker/hdfs-site.xml << EOF
<configuration>
<property>
<name>dfs.replication</name>
<value>1</value>
</property>
<property>
<name>dfs.name.dir</name>
<value>file:///home/docker/dockerinfra/hdfs/namenode </value>
</property>
<property>
<name>dfs.data.dir</name>
<value>file:///home/docker/dockerinfra/hdfs/datanode </value>
</property>
</configuration>
EOF
}

start_docker()
{
	echo "Reloading bash profile...."  
	source ~/.bashrc  

	cd /usr/local/docker/sbin

	echo "Formatting Name Node...."
	/usr/local/docker/bin/hdfs namenode -format

	echo "Docker configured...."

	# To start docker use following scripts 
	# or use start-all.sh.
	echo "Starting docker...."
	/usr/local/docker/sbin/start-dfs.sh  
	/usr/local/docker/sbin/start-yarn.sh
}


###### MAIN #######
clear

echo "Starting docker installations..."

setup
install_java
install_ssh

# Check docker directory
if [ ! -d ${DOCKER_DIR} ]; then
	mkdir ${DOCKER_DIR}
fi

if [ ! -f ${DOCKER_DIR}/.downloaded ]; then
	install_docker
fi

echo "Docker installed successfully...."  
cd ~  

# Now start docker
start_docker

# Test it
jps

# To stop docker use following scripts 
# or use stop-all.sh.
echo "Stopping docker...."  
/usr/local/docker/sbin/stop-dfs.sh  
/usr/local/docker/sbin/stop-yarn.sh

echo "DONE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  