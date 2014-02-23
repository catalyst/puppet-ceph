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
# Handles ceph keys (cephx), generates keys, creates keyring files, injects
# keys into or delete keys from the cluster/keyring via ceph and ceph-autotool
# tools.
#
### == Name
#
# The full ceph ID name, e.g. 'client.admin' or 'mon.'.
#
### == Parameters
#
# [*secret*] Key secret.
#   Mandatory.
#
# [*keyring_path*] Path to the keyring file.
#   Optional. Absolute path to the keyring file, including the file name.
#   Defaults to /etc/ceph/${title}keyring.
#
# [*cap_mon*] cephx capabilities for MON access.
#   Optional. e.g. 'allow *'
#   Defaults to 'undef'.
#
# [*cap_osd*] cephx capabilities for OSD access.
#   Optional. e.g. 'allow *'
#   Defaults to 'undef'.
#
# [*cap_mds*] cephx capabilities for MDS access.
#   Optional. e.g. 'allow *'
#   Defaults to 'undef'.
#
# [*user*] Owner of the keyring file.
#   Optional. Defaults to 'root'.
#
# [*group*] Group of the keyring file.
#   Optional. Defaults to 'root'.
#
# [*mode*] Mode (permissions) of the keyring file.
#   Optional. Defaults to 0600.
#
# [*inject*] True if the key should be injected into the cluster.
#   Optional. Boolean value (true to inject the key).
#   Default to false.
#
# [*ensure*] 'present' or 'absent'.
#   Optional. Should the given key be present or absent in the system.
#   Defaults to 'present'.
#
define ceph::key (
  $secret,
  $keyring_path = "/etc/ceph/ceph.${name}.keyring",
  $cap_mon = '',
  $cap_osd = '',
  $cap_mds = '',
  $user = 'root',
  $group = 'root',
  $mode = 0600,
  $inject = false,
) {

  $caps = "--cap mon '${cap_mon}' --cap osd '${cap_osd}' --cap mds '${cap_mds}'"

  # this allows multiple defines for the same 'keyring file',
  # which is supported by ceph-authtool
  if ! defined(File[$keyring_path]) {
    exec {"${keyring_path}-touch":
      command => "touch ${keyring_path}",
      creates => $keyring_path,
      require => Package['ceph'],
    }

    file {$keyring_path:
      ensure  => file,
      owner   => $user,
      group   => $group,
      mode    => $mode,
      require => Exec["${keyring_path}-touch"],
    }
  }

  exec {"ceph-key-${name}":
    command => "ceph-authtool ${keyring_path} --name '${name}' --add-key '${secret}' ${caps}",
    unless  => "grep ${secret} ${keyring_path}",
    require => Package['ceph'],
  }
  File[$keyring_path] -> Exec["ceph-key-${name}"]

  if $inject == true {

    exec {"ceph-injectkey-${name}":
      command => "ceph auth add ${name} --in-file=${keyring_path}",
      unless  => "ceph auth list | grep '${secret}'",
      require => [ Package['ceph'], Exec["ceph-key-${name}"], ],
    }

  }

}
