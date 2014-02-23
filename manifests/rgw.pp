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
# Configures a ceph radosgw.
#
### == Parameters
#
# [*id*] The id of the user. 
#   Mandatory. 
#
# [*key*] The secret key for the id user.
#   Optional. If unset it looks for keyring /etc/ceph/${id}.keyring
#
# [*rgw_data*] The path where the radosgw data should be stored.
#   Optional. Default is '/var/lib/ceph/radosgw/${cluster}-${id}
#
# [*fcgi_file*] Path to the fcgi file.
#   Optional. Default is '/var/www/s3gw.cgi'
#
# [*keyring_path*] Location of keyring.
#   Optional. Default is '/etc/ceph/${id}.keyring'.
#
# [*log_file*] Log file to write to.
#   Optional. Default is '/var/log/ceph/radosgw.log'.
#
# [*rgw_socket_path*] Path to socket file.
#   Optional. Default is '/tmp/radosgw.sock'.
#
# [*rgw_print_continue*] True to send 100 codes to the client.
#   Optional. Default is true.
#
# [*rgw_port*] Port the rados gateway listens.
#   Optional. Default is 443.
# [*enable_ssl*] True to enable ssl.
#   Optional. Default is true.
#
# [*ssl_cert*] Location of ssl certificate.
#   Optional. Default is '/etc/apache2/ssl/apache.crt'.
#
# [*ssl_key*] Location of ssl key.
#   Optional. Default is '/etc/apache2/ssl/apache.key'.
#
# [*ssl_ca*] Location of ssl ca.
#   Optional. Default is '/etc/apache2/ssl/apache.ca'.
#
class ceph::rgw (
  $id,
  $key = undef, #FIXME: do we really need this
  $rgw_data = "/var/lib/ceph/radosgw/ceph-${id}", # FIXME: use ${cluster}
  $fcgi_file = '/var/www/s3gw.fcgi',
  $user = 'www-data',
  $host = $hostname,
  $keyring_path = "/etc/ceph/ceph.${id}.keyring",
  $log_file = '/var/log/ceph/radosgw.log',
  $rgw_dns_name = $fqdn,
  $rgw_socket_path = '/tmp/radosgw.sock',
  $rgw_print_continue = true,
  $rgw_port = 443,
  $enable_ssl = true,
  $ssl_cert = '/etc/apache2/ssl/apache.crt',
  $ssl_key = '/etc/apache2/ssl/apache.key',
  $ssl_ca = '/etc/apache2/ssl/apache.ca',
) {

  Package['ceph'] -> Package['radosgw']

  package {'radosgw':
    ensure => installed,
  }

  ceph_config {
    'client.radosgw.gateway/host':            value => $fqdn;
    'client.radosgw.gateway/user':            value => $user;
    'client.radosgw.gateway/keyring':         value => $keyring_path;
    'client.radosgw.gateway/rgw_socket_path': value => $rgw_socket_path;
    'client.radosgw.gateway/rgw_dns_name':    value => $rgw_dns_name;
    'client.radosgw.gateway/log_file':        value => $log_file;
    'client.radosgw.gateway/rgw_port':        value => $rgw_port;
  }

  # data dir for radosgw
  file {$rgw_data:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  # apache configuration (mods + vhost)
  if ! defined(Class['apache']) {
    class {
      'apache': default_mods => false, 
      default_vhost          => false,
    }
  }

  include apache::mod::alias
  include apache::mod::auth_basic
  apache::mod {'fastcgi': package => 'libapache2-mod-fastcgi', }
  include apache::mod::mime
  include apache::mod::rewrite
  include apache::mod::ssl

  apache::vhost {"${fqdn}-radosgw":
    servername        => $fqdn,
    serveradmin       => 'root@localhost', # FIXME: should be an arg
    port              => $rgw_port,
    docroot           => '/var/www',
    directories       => [{ 
      path            => '/var/www',
      addhandlers     => [ { handler => 'fastcgi-script', extensions => ['.fcgi']} ],
      allow_override  => ['All'],
      options         => ['+ExecCGI'],
      order           => 'allow,deny',
      allow           => 'from all',
      custom_fragment => 'AuthBasicAuthoritative Off',
    }],
    aliases      => $aliases,
    rewrite_rule => '^/([a-zA-Z0-9-_.]*)([/]?.*) /s3gw.fcgi?page=$1&params=$2&%{QUERY_STRING} [E=HTTP_AUTHORIZATION:%{HTTP:Authorization},L]',
    ssl          => $enable_ssl,
    ssl_cert     => $ssl_cert,
    ssl_key      => $ssl_key,
    ssl_ca       => $ssl_ca,
    # FIXME: need to pass this as arg
    access_log_syslog => true,
    error_log_syslog  => true,
    # FIXME: new apache module provides args for fastcgi config
    custom_fragment => "
      FastCgiExternalServer $fcgi_file -socket $rgw_socket_path
      AllowEncodedSlashes On
      ServerSignature Off",
  }

  # radosgw fast-cgi script
  file {$fcgi_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => 0750,
    content => "#!/bin/sh\nexec /usr/bin/radosgw -c /etc/ceph/ceph.conf -n client.radosgw.gateway",
  }

  # radosgw pool setup
  ceph::pool {'.rgw': }
  ceph::pool {'.rgw.control': }
  ceph::pool {'.rgw.gc': }
  ceph::pool {'.log': }
  ceph::pool {'.intent-log': }
  ceph::pool {'.usage': }
  ceph::pool {'.users': }
  ceph::pool {'.users.email': }
  ceph::pool {'.users.swift': }
  ceph::pool {'.users.uid': }

  # radosgw service #FIXME: get it to use built it service manager
  service {'radosgw':
    ensure   => running,
    provider => 'base',
    start    => '/etc/init.d/radosgw start',
    stop     => '/etc/init.d/radosgw stop',
    status   => '/etc/init.d/radosgw status',
  }

  Ceph::Pool <||> -> Package['radosgw'] -> File[$rgw_data] -> Service['radosgw']

  File['/var/www/s3gw.fcgi'] -> Service['httpd']
  
}
