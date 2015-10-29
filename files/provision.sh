#!/bin/bash
#
if [[ "${USER}" -ne 0 ]]; then
  echo "$0 must be run as root."
  exit 1
fi

# determine AWS region
AZ=$(ec2-metadata -z | awk '{print $2}')
REGION=$(echo "$AZ" | sed 's/[[:alpha:]]$//')

AWS="aws --region $REGION"

echo "### Provisioning DataHub..."

echo "### Patching system..."
yum -y update

echo "### Uninstalling upstream Puppet..."
yum -y erase puppet

echo "### Installing utilities..."
yum -y install git jq

cd ~

echo "### Cloning DataHub platform configuration..."
git clone https://github.com/FitnessKeeper/puppet-rk_datahub.git rk_datahub

echo "### Copying secrets..."
touch rk_datahub/data/secrets.yaml \
  && chmod 600 rk_datahub/data/secrets.yaml \
  && $AWS s3 cp s3://rk-devops-${REGION}/secrets/secrets.yaml rk_datahub/data/secrets.yaml

if [ ! -r "rk_datahub/data/secrets.yaml" ]; then
  echo "Populate the secrets.yaml file and then run $0 again."
  exit 0
fi

cd rk_datahub

echo "### Configuring RubyGems..."
yum -y install ruby-devel glibc-devel gcc
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
yum -y install ruby20-augeas
librarian-puppet config path "$PUPPET_MODULE_DIR" --global
librarian-puppet install
ln -s /root/rk_datahub "${PUPPET_MODULE_DIR}/rk_datahub"

echo "### Running Puppet agent..."
mkdir -p /etc/hiera
cat > /etc/hiera/hiera.yaml << 'HIERA'
---
:backends:
  - module_data
HIERA
puppet apply --hiera_config "/etc/hiera/hiera.yaml" --modulepath "$(pwd)/modules:/etc/puppetlabs/code/modules" -e "class { 'rk_datahub': }"

echo "### Disabling Puppet agent..."
puppet resource service puppet ensure=stopped enable=false

cd ..

echo "### Provision complete."
