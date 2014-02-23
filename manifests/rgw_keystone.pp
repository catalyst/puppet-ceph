#
# Copyright (C) 2014 Catalyst IT Limited.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Author: Ricardo Rocha <ricardo@catalyst.net.nz>
#
# Configures ceph radosgw to use keystone auth/authz. 
#
### == Parameters
#
# [*rgw_keystone_url*] The internal or admin url for keystone.
#   Mandatory.
#
# [*rgw_keystone_admin*] The keystone admin token.
#   Mandatory.
#
# [*rgw_keystone_accepted_roles*] Roles to accept from keystone.
#   Optional. Default is 'member, admin, swiftoperator'. 
#   Comma separated list of roles.
#
# [*rgw_keystone_token_cache_size*] How many tokens to keep cached.
#   Optional. Default is 500.
#   Not useful when using PKI as every token is checked.
# 
# [*rgw_keystone_revocation_interval*] Interval to check for expired tokens.
#   Optional. Default is 600 (seconds).
#   Not useful if not using PKI tokens (if not, set to high value).
#
# [*use_pki*] (bool) To determine if keystone is using token_format.
#   Optional. Default is undef.
# 
# [*nss_db_path*] Path to NSS < - > keystone tokens db files.
#   Optional. Default is undef.
#
class ceph::rgw_keystone (
  $rgw_keystone_url,
  $rgw_keystone_admin_token,
  $rgw_keystone_accepted_roles = '_member_, Member, admin',
  $rgw_keystone_token_cache_size = 500,
  $rgw_keystone_revocation_interval = 600,
  $use_pki = undef,
  $nss_db_path = '/var/lib/ceph/nss',
) {

  ceph_config {
    'client.radosgw.gateway/rgw_keystone_url': value                 => $rgw_keystone_url;
    'client.radosgw.gateway/rgw_keystone_admin_token': value         => $rgw_keystone_admin_token;
    'client.radosgw.gateway/rgw_keystone_accepted_roles': value      => $rgw_keystone_accepted_roles;
    'client.radosgw.gateway/rgw_keystone_token_cache_size': value    => $rgw_keystone_token_cache_size;
    'client.radosgw.gateway/rgw_keystone_revocation_interval': value => $rgw_keystone_revocation_interval;
    'client.radosgw.gateway/rgw_s3_auth_use_keystone': value         => true;
    'client.radosgw.gateway/use_pki': value                          => $use_pki;
    'client.radosgw.gateway/nss_db_path': value                      => $nss_db_path;
  }

}
