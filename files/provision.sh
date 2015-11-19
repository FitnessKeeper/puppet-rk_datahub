#!/bin/bash
#
if [[ "${USER}" -ne 0 ]]; then
  echo "$0 must be run as root."
  exit 1
fi

# determine AWS region
AZ=$(ec2metadata --availability-zone)
REGION=$(echo "$AZ" | sed 's/[[:alpha:]]$//')

AWS="aws --region $REGION"

echo "### Provisioning..."

echo "### Patching system..."
export DEBIAN_FRONTEND=noninteractive
APTGET='apt-get -o Dpkg::Options::="--force-confnew" -y'
apt-add-repository "deb http://${REGION}.ec2.archive.ubuntu.com/ubuntu/ trusty-backports main restricted universe multiverse"
aptitude -y update && $APTGET upgrade

echo "### Uninstalling upstream Puppet..."
aptitude -y purge puppet

echo "### Installing utilities..."
aptitude -y install awscli git jq/trusty-backports

cd ~

echo "### Cloning DataHub platform configuration..."
git clone https://github.com/FitnessKeeper/puppet-rk_datahub.git rk_datahub

echo "### Copying secrets..."
for i in 'secrets' 'secrets-common'; do
  touch "rk_datahub/data/${i}.yaml" \
    && chmod 600 "rk_datahub/data/${i}.yaml" \
    && $AWS s3 cp "s3://rk-devops-${REGION}/secrets/${i}.yaml" "rk_datahub/data/${i}.yaml"
done

if [ ! -r "rk_datahub/data/secrets-common.yaml" ]; then
  echo "Populate the secrets-common.yaml file and then run $0 again."
  exit 0
fi

cd rk_datahub

echo "### Configuring RubyGems..."
aptitude -y install ruby-dev libc-dev libaugeas-dev ruby-augeas gcc make
cat > /root/.gemrc << 'GEMRC'
---
install: --nodocument --bindir /usr/local/bin
GEMRC

echo "### Installing Bundler..."
gem install io-console bundler

echo "### Installing other gem dependencies..."
bundle install

echo "### Installing Puppet dependencies..."
export PUPPET_MODULE_DIR='/etc/puppetlabs/code/modules'
librarian-puppet config path "$PUPPET_MODULE_DIR" --global
librarian-puppet install
ln -s /root/rk_datahub "${PUPPET_MODULE_DIR}/rk_datahub"

echo "### Running Puppet agent..."
mkdir -p /var/log/puppet
mkdir -p /etc/hiera
cat > /etc/hiera/hiera.yaml << 'HIERA'
---
:backends:
  - module_data
HIERA
puppet apply \
  --hiera_config "/etc/hiera/hiera.yaml" \
  --modulepath "$(pwd)/modules:/etc/puppetlabs/code/modules" \
  --logdest "/var/log/puppet/provision.log" \
  -e 'class { "rk_datahub": }'

echo "### Cleaning up..."
cd ..
rm -rf rk_datahub
rm -rf /etc/puppetlabs/code/modules/*

echo "### Provision complete."
