# class dbndns::params
#
# Sets a few standard parameters if we're running on a debian derivitive,
# and can therefore expect to find the dbndns package, otherwise fails.

class dbndns::params {
  case $::osfamily {
    'Debian': {
      $service_dir         = '/etc/service'
      $service_search_dir  = '/etc'
      $dnsroots_path       = '/etc/dnsroots.global'
    }
    default: { fail 'Only Debian derivititves are supported at this time' }
  }
}
