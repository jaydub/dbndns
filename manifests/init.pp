# class dbndns
#
# Bootstraps dbndns onto the node, which is good enough to provide
# dnsip and friends. Doesn't set up dnscache or tinydns; use their respective
# subclasses for that.

class dbndns ($purge=false, $purge_logs=false) {
  include dbndns::params
  class { 'dbndns::packages':
    purge => $purge,
  }
  class { 'dbndns::users':
    purge => $purge,
  }
  if $purge {
    if $purge_logs {
      file { '/var/log/dbndns':
        ensure  => absent,
        purge   => true,
        recurse => true,
        force   => true,
      }
    }
  }
  else {
    file { '/var/log/dbndns':
      ensure => directory,
      mode   => '0755',
    }
  }
}
