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
# Creates / removes users and swift users for the radosgw s3/swift API. 
#
### == Parameters
#
# [*user*] Name of the user.
#   Mandatory.
#
# [*key*] Secret key of the user.
#   Optional.
#
# [*swift_user*]
#
# [*swift_key*]
#
define ceph::rgw_user (
  $user,
  $key       = undef,
  $swift_user = undef,
  $swift_key  = undef,
  $access = 'full',
) {

  exec {"rgwuser-${user}":
    command => "radosgw-admin user create --display-name='${user}' --uid='${user}' --secret='${key}'",
    unless  => "radosgw-admin user info --uid='${user}'",
  }

  if $swift_user {
    exec {"rgwsubuser-${user}-${swift_user}":
      command => "radosgw-admin subuser create --uid='${user}' --subuser='${user}:${swift_user}' --access=${access} --key-type=swift --secret=${swift_key}",
      unless  => "radosgw-admin user info --uid='${user}' | grep '${user}:${swift_user}'",
    }
  }

}
