# rk_datahub
#
class rk_datahub (
  $version,
  $repo,
  $java_pkg,
  $user_keys = {},
  $tier = 'production'
) {
  validate_re($tier, '^(production|staging)$', "\$tier must be 'production' or 'staging', not '${tier}'.")



}
