#   Copyright (C) iWeb Technologies Inc.
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
# Author: David Moreau Simard <dmsimard@iweb.com>
# Author: Ricardo Rocha <ricardo@catalyst.net.nz>

# Installs and configures OSDs (ceph object storage daemons)
### == Parameters
# [*osd_data*] The OSDs data location.
#   Optional. Defaults provided by ceph is '/var/lib/ceph/osd/$cluster-$id'.
#
# [*osd_journal*] The path to the OSD’s journal.
#   Optional. Absolute path.
#   Defaults to '/var/lib/ceph/osd/$cluster-$id/journal'
#
# [*osd_journal_size*] The size of the journal in megabytes.
#   Optional. Default provided by Ceph.
#
# [*keyring*] The location of the keyring used by OSDs
#   Optional. Defaults to '/var/lib/ceph/osd/$cluster-$id/keyring'
#
# [*filestore_flusher*] Allows to enable the filestore flusher.
#   Optional. Default provided by Ceph.
#
# [*osd_mkfs_type*] Type of the OSD filesystem.
#   Optional. Defaults to 'xfs'.
#
# [*osd_mkfs_options*] The options used to format the OSD fs.
#   Optional. Defaults to '-f' for XFS.
#
# [*osd_mount_options*] The options used to mount the OSD fs.
#   Optional. Defaults to 'rw,noatime,inode64,nobootwait' for XFS.
#

define ceph::osd (
  $osd_id             = 0,
  $osd_data           = "/var/lib/ceph/osd/ceph-${osd_id}",
  $osd_journal        = "/var/lib/ceph/osd/ceph-${osd_id}/journal",
  $osd_journal_size   = undef,
  $keyring            = "/var/lib/ceph/osd/ceph-${osd_id}/keyring",
  $filestore_flusher  = undef,
  $osd_mkfs_type      = 'xfs',
  $osd_mkfs_options   = '-f',
  $osd_mount_options  = 'rw,noatime,inode64,nobootwait',
) {

  # FIXME: we should probably be using ceph-disk-prepare here (as per blueprint)

  Package['ceph'] -> Ceph::Osd<||>

  # [osd.${osd_id}]
  ceph_config {
    "osd.${osd_id}/osd_data":           value => $osd_data;
    "osd.${osd_id}/osd_journal":        value => $osd_journal;
    "osd.${osd_id}/osd_journal_size":   value => $osd_journal_size;
    "osd.${osd_id}/keyring":            value => $keyring;
    "osd.${osd_id}/filestore_flusher":  value => $filestore_flusher;
    "osd.${osd_id}/osd_mkfs_type":      value => $osd_mkfs_type;
    "osd.${osd_id}/osd_mkfs_options":   value => $osd_mkfs_options;
    "osd.${osd_id}/osd_mount_options":  value => $osd_mount_options;
  }

  exec {"mkfs-${name}":
    command => "mkfs.${osd_mkfs_type} ${osd_mkfs_options} ${name}",
    unless  => "xfs_admin -l ${name}", #FIXME: support other fstypes
  }
  
  file {$osd_data:
    ensure => directory,
  }

  mount {$osd_data:
    ensure  => mounted,
    device  => $name,
    atboot  => true,
    fstype  => $osd_mkfs_type,
    options => $osd_mount_options,
  }

  # make sure we created enough osds
  exec {"osd-create-${osd_id}":
    command => "ceph osd create; touch ${osd_data}/create",
    unless  => "ls ${osd_data}/create",
  }

  exec {"osd-mkfs-${osd_id}":
    command => "ceph-osd -i ${osd_id} --mkfs --mkkey",
    creates => "${osd_data}/keyring",
  }

  exec {"osd-register-${osd_id}":
    command => "ceph auth add osd.${osd_id} osd 'allow *' mon 'allow rwx' -i ${osd_data}/keyring",
    unless  => "ceph auth list | grep osd.${osd_id}",
  }

  service {"ceph-osd.${osd_id}":
    ensure   => 'running',
    provider => 'base',
    start    => "start ceph-osd id=${osd_id}",
    stop     => "stop ceph-osd id=${osd_id}",
    status   => "status ceph-osd id=${osd_id}",
  }

  File[$osd_data]
  -> Mount[$osd_data] 
  -> Exec["osd-create-${osd_id}"] 
  -> Exec["osd-mkfs-${osd_id}"] 
  -> Exec["osd-register-${osd_id}"] 
  -> Service["ceph-osd.${osd_id}"]

}
