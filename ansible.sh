#!/usr/bin/env bash

set -e
set -x

SEP="-----------------------------------------"
LOG="seed/ansible:"

echo ${SEP} && echo "${LOG} Check if server already bootstrapped"
if [ -d "/etc/ansible/facts.d" ] && [ "$(cat /etc/ansible/facts.d/seed.fact)" = "{\"planted\": true}" ]; then
    echo "${LOG} Server already bootstrapped... Stopping."
    exit 0
fi

PROJECT_DIR=`realpath $(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)`

echo ${SEP} && echo "${LOG} Checking prerequisites"
if [ -z "${PERSONAL_ACCESS_TOKEN}" ]; then
    echo "${LOG} Env var 'PERSONAL_ACCESS_TOKEN' should be defined."
    exit 2
else
    grep PERSONAL_ACCESS_TOKEN /root/.bashrc \
    || echo export PERSONAL_ACCESS_TOKEN=\"${PERSONAL_ACCESS_TOKEN}\" >> /root/.bashrc
fi
if [ -z "${RUNNER_NAME}" ]; then
    echo "${LOG} Env var 'RUNNER_NAME' should be defined."
    exit 2
else
    grep RUNNER_NAME /root/.bashrc \
    || echo export RUNNER_NAME=\"${RUNNER_NAME}\" >> /root/.bashrc
fi

echo "${LOG} Install CentOS backports repository"
yum makecache -y
yum install centos-release-scl -y

echo "${LOG} Install mandatory packages"
yum makecache -y
yum install         \
    automake        \
    bash-completion \
    git             \
    libxml2         \
    libxml2-devel   \
    libxslt         \
    libxslt-devel   \
    make            \
    openssl-devel   \
    perl-devel      \
    rh-python38-python-setuptools   \
    rh-python38-python-devel        \
    rh-python38-python-pip          \
    rh-python38-python-wheel        \
    sudo            \
    unzip           \
    wget            \
    -y

echo "${LOG} Install direnv"
wget https://github.com/direnv/direnv/releases/download/v2.28.0/direnv.linux-amd64 -O /usr/local/bin/direnv
chmod 755 /usr/local/bin/direnv

echo ${SEP} && echo "${LOG} Add Python3 backport install to default PATH"
grep PATH /etc/environment \
|| echo 'PATH="/usr/bin:/usr/local/bin:/opt/rh/rh-python38/root/usr/bin:/opt/rh/rh-python38/root/usr/local/bin"' >> /etc/environment

echo ${SEP} && echo "${LOG} Generate key for Github/host interactions"
[ ! -d "/root/.ssh/id_github" ] && mkdir -p /root/.ssh && chmod 700 /root/.ssh
[ ! -e "/root/.ssh/id_github" ] && ssh-keygen -t ed25519 -N "" -C "" -f /root/.ssh/id_github
grep "Host github.com" /root/.ssh/config || \
    echo "Host github.com" >> /root/.ssh/config && \
    echo "  IdentityFile ~/.ssh/id_github" >> /root/.ssh/config

echo ${SEP} && echo "${LOG} Please add this key to deploy keys at:"
echo "   key ==> $(cat /root/.ssh/id_github.pub)"
echo "   url ==> https://github.com/la-francaise-com/ansible-operation-center/settings/keys"
echo 
read -p "Then press Enter to continue" </dev/tty

echo "${LOG} Disable selinux"
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

echo ${SEP} && echo "${LOG} Clone ansible-operation-center repository"
git clone git@github.com:la-francaise-com/ansible-operation-center.git

echo ${SEP} && echo "${LOG} Install pip requirements"
pip3 install -U -r ansible-operation-center/requirements.txt

echo ${SEP} && echo "${LOG} Mark server as bootstrapped"
mkdir -p /etc/ansible/facts.d
echo "{\"planted\": true}" > /etc/ansible/facts.d/seed.fact
