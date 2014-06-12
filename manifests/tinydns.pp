# Class: dbndns::dnscache
#
# Sets up a tinydns instance on some ip address.
#
# The default installation behaviour is very similar to the behaviour of the
# tinydns-conf tool, except that the multilog run script pulls configuration
# information from it's own env directory, and log/main is symlinked to
# /var/log/dbndns/tinydns.
#
# It's important to remember that if you want to run tinydns and dnscache
# on the same interface, you'll need to have set up a sub-interface on a
# separate IP address.
#
# Parameters:
#  The default parameters will produce a tinydns instance listening and
#    accepting connections on 127.0.0.1, suitable for a local cache server.
#  service_name - name of the directory containing all of tinydns's
#    configuration
#  ip - the IP address to listen on for connections. Defaults to 127.0.0.1
#  log_size - the size in byte of each log file managed by multilog. Defaults to
#    99999 bytes.
#  log_num - the number of logs kept beyond 'current'. Defaults to 10
#  log_flags - a hook to allow you to send arbitrary command line instructions
#    to multilog. Defaults to nothing
#  ensure - toggles the state of the service between 'running' and 'stopped'.
#    Defaults to 'running'
#  purge - set this to permanently shut down the service and remove all it's
#    configuration. This flag propagates to the dbndns::cache_server,
#    dbndns::cache_reverse_server, and dbndns::cache_access types
#  purge_logs - purge the logs in addition to configuration if purge is set.
#    does nothing if purge is not set
#

class dbndns::tinydns (
  $service_name = 'tinydns',
  $ip           = '127.0.0.1',
  $log_size     = 99999,
  $log_num      = 10,
  $log_flags    = '',
  $ensure       = 'running',
  $purge        = $dbndns::purge,
  $purge_logs   = false,
)
{
  include dbndns::params
  $base_path = "${dbndns::params::service_search_dir}/${service_name}"

  if $purge == true {
    file { "${dbndns::params::service_dir}/${service_name}":
      # prevent svscan from restarting if supervise processes go down.
      ensure => 'absent',
    } -> # and then...
    exec { 'stop_supervise':
      # Use -x to cause supervise to exit once tinydns and multilog exit
      provider    => shell,
      cwd         => '/',
      command     => "svc -x -t  ${base_path}/log ${base_path}",
    } -> # and then...
    file { $base_path:
      ensure  => 'absent',
      purge   => true,
      recurse => true,
      force   => true,
    } -> # and then...
    user { 'tinydns':
      ensure => absent,
    }
    if $purge_logs {
      file { '/var/log/dbndns/tinydns':
        ensure  => absent,
        purge   => true,
        recurse => true,
        force   => true,
      }
    }
  }
  else {
    ### Users
    user { 'tinydns':
      ensure   => present,
      gid      => 'nogroup',
      home     => "${base_path}/root",
      shell    => '/bin/false',
      password => '*',
      system   => true,
    }
    ### Directories
    # We set the setgid bit, and also the sticky bit for backwards
    # compatability with older daemontools behaviour, but it's not
    # clear that we still need to.
    file { $base_path:
      ensure => directory,
      mode   => '3755'
    }
    file { "${base_path}/env":
      ensure => directory,
    }
    file { "${base_path}/root":
      ensure => directory,
    }
    # exec step to build data.cdb
    exec { 'data.cdb':
      provider    => 'shell',
      cwd         => "${base_path}/root",
      command     => 'tinydns-data',
      refreshonly => true,
    }
    # Base file for our static entries, each added by concat::fragement
    # resources
    concat { 'dnsdata':
      path   => "${base_path}/root/data",
      mode   => '0644',
      force  => true,
      warn   => true,
      notify => Exec['data.cdb'],
    }
    file { "${base_path}/log":
      ensure => directory,
    }
    file { "${base_path}/log/env":
      ensure => directory,
      before => Service[$service_name],
    }
    file { '/var/log/dbndns/tinydns':
      ensure => directory,
      owner  => 'dnslog',
      group  => 'nogroup',
      before => Service[$service_name],
    }
    file { "${base_path}/log/main":
      ensure => link,
      target => '/var/log/dbndns/tinydns',
    }
    ### 'run' scripts
    file { "${base_path}/log/run":
      ensure => file,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/dbndns/run-multilog',
    }
    file { "${base_path}/run":
      ensure  => file,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      source  => 'puppet:///modules/dbndns/run-tinydns',
      require => File["${base_path}/log/run"]
    }
    ### Extra files
    file { "${base_path}/log/status":
      ensure => file,
      mode   => '0644',
      owner  => 'dnslog',
      group  => 'nogroup',
    }
    ### Env configuration
    file { "${base_path}/env/IP":
      ensure  => file,
      content => $ip,
      notify  => Service[$service_name],
    }
    file { "${base_path}/env/ROOT":
      ensure  => file,
      content => "${base_path}/root",
      notify  => Service[$service_name],
    }
    ### Logging env configuration
    file { "${base_path}/log/env/LOGSIZE":
      ensure  => file,
      content => $log_size,
      notify  => Exec['restart_tinydns_multilog'],
    }
    # Can't use a bare variable due to PUP-1768
    file { "${base_path}/log/env/LOGNUM":
      ensure  => file,
      content => $log_num,
      notify  => Exec['restart_tinydns_multilog'],
    }
    file { "${base_path}/log/env/FLAGS":
      ensure  => file,
      content => $log_flags,
      notify  => Exec['restart_tinydns_multilog'],
    }
    file { "${base_path}/log/env/LOGROOT":
      ensure  => file,
      content => '/var/log/dbndns/tinydns',
      notify  => Exec['restart_tinydns_multilog'],
    }
    # Artificial restart for multilog, as it's usually automatically
    # run by it's parent service.
    exec { 'restart_tinydns_multilog':
      cwd         => "${base_path}/log/",
      command     => '/usr/bin/svc -t .',
      refreshonly => true,
      require     => Service[$service_name],
    }
    ### Service control
    service { $service_name:
      ensure   => $ensure,
      provider => 'daemontools',
      # we need all of these resources to exist before we start
      # the service; trigger deferal was being wierd.
      require  => [File["${base_path}/env/IP"],
                  File["${base_path}/env/ROOT"],
                  ],
    }
  }
}
