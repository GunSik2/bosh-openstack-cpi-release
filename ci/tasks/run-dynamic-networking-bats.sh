#!/usr/bin/env bash

set -x

ensure_not_replace_value() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

ensure_not_replace_value bat_stemcell_name
ensure_not_replace_value bats_private_key_data
ensure_not_replace_value openstack_bat_security_group
ensure_not_replace_value openstack_bats_flavor_with_ephemeral_disk
ensure_not_replace_value openstack_bats_flavor_with_no_ephemeral_disk
ensure_not_replace_value openstack_bats_network_id
ensure_not_replace_value bosh_director_public_ip
ensure_not_replace_value desired_vcap_user_password 
ensure_not_replace_value bats_vm_floating_ip

ensure_not_replace_value bat_stemcell_name

####
# TODO:
# - check that all environment variables defined in pipeline.yml are set
# - reference stemcell like vCloud bats job does
# - upload new keypair to bluebox/mirantis with `external-cpi` tag to tell which vms have been deployed by which ci
# - use heredoc to generate deployment spec
# - copy rogue vm check from vSphere pipeline
####

cpi_release_name=bosh-openstack-cpi
working_dir=$PWD

mkdir -p $working_dir/keys
echo "$bats_private_key_data" > $working_dir/keys/bats.pem

eval $(ssh-agent)
chmod go-r $working_dir/keys/bats.pem
ssh-add $working_dir/keys/bats.pem

source /etc/profile.d/chruby.sh
chruby 2.1.2

# checked by BATs environment helper (bosh-acceptance-tests.git/lib/bat/env.rb)
export BAT_STEMCELL="${working_dir}/stemcell/stemcell.tgz"
export BAT_VCAP_PRIVATE_KEY="$working_dir/keys/bats.pem"
export BAT_DIRECTOR=${bosh_director_public_ip}
export BAT_VCAP_PASSWORD=${desired_vcap_user_password}
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
  key_name: external-cpi
  uuid: $(bosh status --uuid)
  vip: ${bats_vm_floating_ip}
  instance_type: ${openstack_bats_flavor_with_ephemeral_disk}
  pool_size: 1
  instances: 1
  flavor_with_no_ephemeral_disk: ${openstack_bats_flavor_with_no_ephemeral_disk}
  stemcell:
    name: ${bat_stemcell_name}
    version: latest
  networks:
  - name: default
    type: dynamic
    cloud_properties:
      net_id: ${openstack_bats_network_id}
      security_groups: [${openstack_bat_security_group}]
EOF

cd bats

cat > "Gemfile" <<EOF
# encoding: UTF-8
source 'https://rubygems.org'
gem 'bosh_common'
gem 'bosh-core'
gem 'bosh_cpi'
gem 'bosh_cli'
gem 'rake', '~>10.0'
gem 'rspec', '~> 3.0.0'
gem 'rspec-its'
gem 'rspec-instafail'
EOF

cat > "Gemfile.lock" <<EOF
GEM
  remote: https://rubygems.org/
  specs:
    CFPropertyList (2.3.1)
    aws-sdk (1.60.2)
      aws-sdk-v1 (= 1.60.2)
    aws-sdk-v1 (1.60.2)
      json (~> 1.4)
      nokogiri (>= 1.4.4)
    blobstore_client (1.2957.0)
      aws-sdk (= 1.60.2)
      bosh_common (~> 1.2957.0)
      fog (~> 1.27.0)
      httpclient (= 2.4.0)
      multi_json (~> 1.1)
      ruby-atmos-pure (~> 1.0.5)
    bosh-core (1.2957.0)
      gibberish (~> 1.4.0)
      yajl-ruby (~> 1.2.0)
    bosh-template (1.2957.0)
      semi_semantic (~> 1.1.0)
    bosh_cli (1.2957.0)
      blobstore_client (~> 1.2957.0)
      bosh-template (~> 1.2957.0)
      bosh_common (~> 1.2957.0)
      cf-uaa-lib (~> 3.2.1)
      highline (~> 1.6.2)
      httpclient (= 2.4.0)
      json_pure (~> 1.7)
      minitar (~> 0.5.4)
      net-scp (~> 1.1.0)
      net-ssh (>= 2.2.1)
      net-ssh-gateway (~> 1.2.0)
      netaddr (~> 1.5.0)
      progressbar (~> 0.9.0)
      terminal-table (~> 1.4.3)
    bosh_common (1.2957.0)
      logging (~> 1.8.2)
      semi_semantic (~> 1.1.0)
    bosh_cpi (1.2957.0)
      bosh_common (~> 1.2957.0)
      logging (~> 1.8.2)
      membrane (~> 1.1.0)
    builder (3.2.2)
    cf-uaa-lib (3.2.1)
      multi_json
    diff-lcs (1.2.5)
    excon (0.45.3)
    fission (0.5.0)
      CFPropertyList (~> 2.2)
    fog (1.27.0)
      fog-atmos
      fog-aws (~> 0.0)
      fog-brightbox (~> 0.4)
      fog-core (~> 1.27, >= 1.27.3)
      fog-ecloud
      fog-json
      fog-profitbricks
      fog-radosgw (>= 0.0.2)
      fog-sakuracloud (>= 0.0.4)
      fog-serverlove
      fog-softlayer
      fog-storm_on_demand
      fog-terremark
      fog-vmfusion
      fog-voxel
      fog-xml (~> 0.1.1)
      ipaddress (~> 0.5)
      nokogiri (~> 1.5, >= 1.5.11)
    fog-atmos (0.1.0)
      fog-core
      fog-xml
    fog-aws (0.1.2)
      fog-core (~> 1.27)
      fog-json (~> 1.0)
      fog-xml (~> 0.1)
      ipaddress (~> 0.8)
    fog-brightbox (0.7.1)
      fog-core (~> 1.22)
      fog-json
      inflecto (~> 0.0.2)
    fog-core (1.30.0)
      builder
      excon (~> 0.45)
      formatador (~> 0.2)
      mime-types
      net-scp (~> 1.1)
      net-ssh (>= 2.1.3)
    fog-ecloud (0.1.1)
      fog-core
      fog-xml
    fog-json (1.0.1)
      fog-core (~> 1.0)
      multi_json (~> 1.0)
    fog-profitbricks (0.0.2)
      fog-core
      fog-xml
      nokogiri
    fog-radosgw (0.0.4)
      fog-core (>= 1.21.0)
      fog-json
      fog-xml (>= 0.0.1)
    fog-sakuracloud (1.0.1)
      fog-core
      fog-json
    fog-serverlove (0.1.2)
      fog-core
      fog-json
    fog-softlayer (0.4.5)
      fog-core
      fog-json
    fog-storm_on_demand (0.1.1)
      fog-core
      fog-json
    fog-terremark (0.1.0)
      fog-core
      fog-xml
    fog-vmfusion (0.1.0)
      fission
      fog-core
    fog-voxel (0.1.0)
      fog-core
      fog-xml
    fog-xml (0.1.2)
      fog-core
      nokogiri (~> 1.5, >= 1.5.11)
    formatador (0.2.5)
    gibberish (1.4.0)
    highline (1.6.21)
    httpclient (2.4.0)
    inflecto (0.0.2)
    ipaddress (0.8.0)
    json (1.8.2)
    json_pure (1.8.2)
    little-plugger (1.1.3)
    log4r (1.1.10)
    logging (1.8.2)
      little-plugger (>= 1.1.3)
      multi_json (>= 1.8.4)
    membrane (1.1.0)
    mime-types (2.5)
    mini_portile (0.6.2)
    minitar (0.5.4)
    multi_json (1.11.0)
    net-scp (1.1.2)
      net-ssh (>= 2.6.5)
    net-ssh (2.9.2)
    net-ssh-gateway (1.2.0)
      net-ssh (>= 2.6.5)
    netaddr (1.5.0)
    nokogiri (1.6.6.2)
      mini_portile (~> 0.6.0)
    progressbar (0.9.2)
    rake (10.4.2)
    rspec (3.0.0)
      rspec-core (~> 3.0.0)
      rspec-expectations (~> 3.0.0)
      rspec-mocks (~> 3.0.0)
    rspec-core (3.0.4)
      rspec-support (~> 3.0.0)
    rspec-expectations (3.0.4)
      diff-lcs (>= 1.2.0, < 2.0)
      rspec-support (~> 3.0.0)
    rspec-instafail (0.2.6)
      rspec
    rspec-its (1.2.0)
      rspec-core (>= 3.0.0)
      rspec-expectations (>= 3.0.0)
    rspec-mocks (3.0.4)
      rspec-support (~> 3.0.0)
    rspec-support (3.0.4)
    ruby-atmos-pure (1.0.5)
      log4r (>= 1.1.9)
      ruby-hmac (>= 0.4.0)
    ruby-hmac (0.4.0)
    semi_semantic (1.1.0)
    terminal-table (1.4.5)
    yajl-ruby (1.2.1)
PLATFORMS
  ruby
DEPENDENCIES
  bosh-core
  bosh_cli
  bosh_common
  bosh_cpi
  httpclient
  json
  minitar
  net-ssh
  rake (~> 10.0)
  rspec (~> 3.0.0)
  rspec-instafail
  rspec-its
EOF

bundle install
bundle exec rspec spec
