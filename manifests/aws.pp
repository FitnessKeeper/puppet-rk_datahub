# rk_datahub::aws
#
class rk_datahub::aws (
  $prereqs,
  $cfn_url,
  $cfn_dir,
) {
  $cfn_tarball = "${cfn_dir}.tar.gz"

  Exec {
    path      => '/usr/bin:/usr/sbin:/bin:/sbin',
    logoutput => 'on_failure',
  }

  package { $prereqs:
    ensure => present,
  } ->

  wget::fetch { 'cfn_url':
    source      => $cfn_url,
    destination => $cfn_tarball,
  } ->

  file { $cfn_dir:
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  } ->

  exec { 'cfn_untar':
    command => "tar zxf $cfn_tarball --strip-components=1 -C $cfn_dir",
  } ->

  exec { 'cfn_install':
    command => "easy_install $cfn_dir",
    creates => '/usr/local/bin/cfn-init',
  }
}
