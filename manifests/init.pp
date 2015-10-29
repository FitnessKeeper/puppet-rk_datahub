# rk_datahub
#
class rk_datahub (
  $version,
  $repo,
  $java_pkg,
  $user_keys = {},
  $tier = 'production'
) {
  validate_re($::osfamily, '^Debian$', "DataHub requires a Debian-derived Linux distribution, not '${::osfamily}'.")
  validate_re($tier, '^(production|staging)$', "\$tier must be 'production' or 'staging', not '${tier}'.")

  $user_key = $user_keys[$tier]

  $datahub_remote_pkg = "${repo}/DataHub_${version}.deb"
  $datahub_local_pkg = "/root/datahub.deb"



  wget::fetch { $datahub_remote_pkg:
    destination => $datahub_local_pkg,
    timeout     => 0,
    verbose     => true,
  } ->

  package { 'datahub':
    ensure   => installed,
    provider => 'dpkg',
    source   => $datahub_local_pkg,
  } ->

  file { '/etc/datahub/datahub.config':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('rk_datahub/datahub.config.erb'),
  } ~>

  service { 'datahub':
    ensure     => stopped,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }

}
