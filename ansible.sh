#!/usr/bin/env bash
GREEN='\033[1;32m'
RED='\033[1;31m'
NOCOLOR='\033[0m'

SEPARATOR="-----------------------------------------"
LOG_PREFIX="=> seed/ansible:"

info() {
    echo
    echo ${SEPARATOR}
    echo -e "${GREEN}${LOG_PREFIX}${NOCOLOR} ${1}"
    echo ${SEPARATOR}
    echo
}

warn() {
    echo
    echo ${SEPARATOR}
    echo -e "${RED}${LOG_PREFIX}${NC} ${1}"
    echo ${SEPARATOR}
    echo
}

info "Check if server already bootstrapped"
if [ -d "/etc/ansible/facts.d" ] && [ "$(cat /etc/ansible/facts.d/seed.fact)" = "{\"planted\": true}" ]; then
    info "Server already bootstrapped... Stopping."
    exit 0
fi

PROJECT_DIR=`realpath $(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)`

info "Checking prerequisites"
if [ -z "${PERSONAL_ACCESS_TOKEN}" ]; then
    warn "Env var 'PERSONAL_ACCESS_TOKEN' should be defined."
    exit 2
else
    grep PERSONAL_ACCESS_TOKEN /root/.bashrc \
    || echo export PERSONAL_ACCESS_TOKEN=\"${PERSONAL_ACCESS_TOKEN}\" >> /root/.bashrc
fi
if [ -z "${RUNNER_NAME}" ]; then
    warn "Env var 'RUNNER_NAME' should be defined."
    exit 2
else
    grep RUNNER_NAME /root/.bashrc \
    || echo export RUNNER_NAME=\"${RUNNER_NAME}\" >> /root/.bashrc
fi

info "Install CentOS backports repository"
yum makecache -y
yum install centos-release-scl -y

info "Install system dependencies"
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

wget https://github.com/direnv/direnv/releases/download/v2.28.0/direnv.linux-amd64 -O /usr/local/bin/direnv
chmod 755 /usr/local/bin/direnv

info "Add Python3 backport install to default PATH"
grep PATH /etc/environment \
    || echo 'PATH="/usr/bin:/usr/local/bin:/opt/rh/rh-python38/root/usr/bin:/opt/rh/rh-python38/root/usr/local/bin"' >> /etc/environment
[ ! -L /usr/bin/python3 ] && ln -s /opt/rh/rh-python38/root/usr/bin/python3 /usr/bin/python3
[ ! -L /usr/bin/pip3 ] && ln -s /opt/rh/rh-python38/root/usr/bin/pip3 /usr/bin/pip3

info "Disable selinux"
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i -e 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config

info "Generate key for Github/host interactions"
[ ! -d "/root/.ssh/id_github" ] && mkdir -p /root/.ssh && chmod 700 /root/.ssh
[ ! -e "/root/.ssh/id_github" ] && ssh-keygen -t ed25519 -N "" -C "" -f /root/.ssh/id_github
grep "Host github.com" /root/.ssh/config &> /dev/null || \
cat > /root/.ssh/config << EOF
Host github.com
  IdentityFile ~/.ssh/id_github
EOF

echo
echo ${SEP}
echo -e "  ${GREEN}Register this key:${NOCOLOR} $(cat /root/.ssh/id_github.pub)"
echo -e "  ${GREEN}as a deploy key  :${NOCOLOR} https://github.com/la-francaise-com/ansible-operation-center/settings/keys"
echo ${SEP}
read -p "Then press <ENTER> to continue" </dev/tty
echo

info "Clone ansible-operation-center repository"
git clone git@github.com:la-francaise-com/ansible-operation-center.git

info "Install python3 dependencies"
pip3 install -U -r ansible-operation-center/requirements.txt

info "Mark server as bootstrapped"
mkdir -p /etc/ansible/facts.d
echo "{\"planted\": true}" > /etc/ansible/facts.d/seed.fact

info "Server needs a reboot... now. (HINT: type 'reboot' and press <ENTER>)"
