#!/usr/bin/env bash

set -x

source bosh-cpi-src-in/ci/tasks/utils.sh

ensure_not_replace_value stemcell_name
ensure_not_replace_value bats_vm_floating_ip
ensure_not_replace_value bosh_admin_password
ensure_not_replace_value bosh_director_public_ip
ensure_not_replace_value openstack_flavor_with_ephemeral_disk
ensure_not_replace_value openstack_flavor_with_no_ephemeral_disk
ensure_not_replace_value openstack_security_group
ensure_not_replace_value primary_network_id
ensure_not_replace_value private_key_data
ensure_not_replace_value resource_pool_key_name

working_dir=$PWD

mkdir -p $working_dir/keys
export BAT_VCAP_PRIVATE_KEY="$working_dir/keys/bats.pem"
echo "$private_key_data" > $BAT_VCAP_PRIVATE_KEY

eval $(ssh-agent)
chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

source /etc/profile.d/chruby.sh
chruby 2.1.2

bosh_vcap_password_hash=$(ruby -e 'require "securerandom";puts ENV["bosh_admin_password"].crypt("$6$#{SecureRandom.base64(14)}")')

# checked by BATs environment helper (bosh-acceptance-tests.git/lib/bat/env.rb)
export BAT_STEMCELL="${working_dir}/stemcell/stemcell.tgz"
export BAT_DIRECTOR=${bosh_director_public_ip}
export BAT_DIRECTOR_PASSWORD=${bosh_admin_password}
export BAT_VCAP_PASSWORD=${bosh_admin_password}
export BAT_DNS_HOST=${bosh_director_public_ip}
export BAT_INFRASTRUCTURE='openstack'
export BAT_NETWORKING='dynamic'

echo "using bosh CLI version..."
bosh version

bosh -n target $bosh_director_public_ip

export BAT_DEPLOYMENT_SPEC="${working_dir}/bats-config.yml"
cat > $BAT_DEPLOYMENT_SPEC <<EOF
---
cpi: openstack
properties:
  uuid: $(bosh status --uuid)
  vip: ${bats_vm_floating_ip}
  instance_type: ${openstack_flavor_with_ephemeral_disk}
  pool_size: 1
  instances: 1
  flavor_with_no_ephemeral_disk: ${openstack_flavor_with_no_ephemeral_disk}
  stemcell:
    name: ${stemcell_name}
    version: latest
  networks:
    - name: default
      type: dynamic
      cloud_properties:
        net_id: ${primary_network_id}
        security_groups: [${openstack_security_group}]
  password: ${bosh_vcap_password_hash}
EOF

cd bats
./write_gemfile

bundle install
bundle exec rspec --tag ~manual_networking spec
