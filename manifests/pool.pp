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
# Manages operations on the pools in the cluster, such as creating or deleting
# pools, setting PG/PGP numbers, number of replicas, etc.
#
### == Name
#
# The name of the pool.
#
### == Parameters
#
# [*create*] If to create a new pool.
#   Optional. Default is true.
#
# [*delete*] If to delete an existing pool.
#   Optional. Default is false.
#
# [*pg_num*] Number of PGs for the pool.
#   Optional. Default is 2. 
#   Number of Placement Groups (PGs) for a pool, if the pool already
#   exists this may increase the number of PGs if the current value is lower.
#
# [*pgp_num*] Same as for pg_num.
#   Optional. Default is undef.
#
# [*size*] Replica level for the pool.
#   Optional. Default is undef.
#   Increase or decrease the replica level of a pool.
#
define ceph::pool (
  $create = true,
  $delete = false,
  $pg_num = 2,
  $pgp_num = undef,
  $size = undef,
) {

  Package['ceph'] -> Ceph::Pool<||>

  if $create and $delete {
    fail("create (set to $create) and delete (set to $delete) are mutually exclusive")
  }

  if $create {
    exec {"create-${name}":
      command => "ceph osd pool create ${name} ${pg_num}",
      unless  => "ceph osd lspools | grep ' ${name},'",
    }

    exec {"set-${name}-pg_num":
      command => "ceph osd pool set ${name} pg_num ${pg_num}",
      unless  => "ceph osd pool get ${name} pg_num | grep 'pg_num: ${pg_num}'",
      require => Exec["create-${name}"],
    }

    if $pgp_num {
      exec {"set-${name}-pgp_num":
        command => "ceph osd pool set ${name} pgp_num ${pgp_num}",
        unless  => "ceph osd pool get ${name} pgp_num | grep 'pgp_num: ${pgp_num}'",
        require => Exec["create-${name}"],
      }
    }

    if $size {
      exec {"set-${name}-size":
        command => "ceph osd pool set ${name} size ${size}",
        unless  => "ceph osd pool get ${name} size | grep 'size: ${size}'",
        require => Exec["create-${name}"],
      }
    }
  }

  if $delete {
    exec {"delete-${name}":
      command => "ceph osd pool delete ${name}",
      onlyif  => "ceph osd lspools | grep ${name}",
    }
  }

}
