# Class: dbndns::dnscache
#
# Sets up a dnscache instance on some ip address.
#
# The default installation behaviour is very similar to the behaviour of the
# dnscache-conf tool, except that the multilog run script pulls configuration
# information from it's own env directory, and log/main is symlinked to
# /var/log/dbndns/dnscache.
#
# It's important to remember that if you want to run dnscache and tinydns
# on the same interface, you'll need to have set up a sub-interface on a
# separate IP address.
#
#
# Parameters:
#  The default parameters will produce a dnscache instance listening and
#    accepting connections on 127.0.0.1, suitable for a local cache server.
#  service_name - name of the directory containing all of dnscache's
#    configuration
#  ip - the IP address to listen on for connections. Defaults to 127.0.0.1
#  ipsend - the address dnscache sends from when resolving addresses. Defaults
#    to 0.0.0.0, however you may wish to set this to the same address as the
#    listening address if you have more than one interface on different
#    networks. Don't set it to the loop back address, however.
#  cachesize - limit on the size of the cache data structures in bytes. The
#    default is 1M, which is adequate for a workstation cache, but likely
#    insufficient for a local network cache. See
#    http://cr.yp.to/djbdns/cachesize.html for advice as to how to select an
#    accurate cache size.
#  datalimit - limit on the overall data segment size used by dnscache. The
#    default is '0' which causes it to be set to cachesize + 2Mb, which is more
#    than enough for most installations. If you're setting an especially large
#    cache, and expecting to handle a lot of request traffic, you may want to
#    bump that up a bit by setting an explicit limit
#  forwardonly - if set to a list of cache server IPs, these will be set in
#    servers/@ instead of the root servers, and dnscache will forward queries to
#    those caches the same way that a client does, rather than contacting a
#    chain of servers according to NS records. Defaults to false; servers/@ is
#    set to the root servers found in /etc/dnsroots.global
#  hidettl - if true, all dns responses have TTL set to 0, which was the
#    default behaviour in dnscache versions prior to 1.03. This will disrupt
#    the behaviour of e.g. Window local caching.
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
# See also: dbndns::cache_server and dbndns::cache_reverse_server types to set
# up access to local dns servers, and the dbndns::cache_access type to manage
# access control.

class dbndns::dnscache (
  $service_name = 'dnscache',
  $ip           = '127.0.0.1',
  $ipsend       = '0.0.0.0',
  $cachesize    = 1000000,
  $datalimit    = 0,
  $forwardonly  = false,
  $hidettl      = false,
  $log_size     = 99999,
  $log_num      = 10,
  $log_flags    = '',
  $ensure       = 'running',
  $purge        = $dbndns::purge,
  $purge_logs   = false,
)
{
  # I *should* be able to do this in the arguments...
  if $ipsend == 0 {
    $derived_ipsend = $ip
  }
  else {
    $derived_ipsend = $ipsend
  }

  if $datalimit == 0 {
    $derived_datalimit = $cachesize + 2000000
  }
  else {
    $derived_datalimit = $datalimit
  }
  include dbndns::params
  $base_path = "${dbndns::params::service_search_dir}/${service_name}"

  if $purge == true {
    file { "${dbndns::params::service_dir}/${service_name}":
      # prevent svscan from restarting if supervise processes go down.
      ensure => 'absent',
    } -> # and then...
    exec { 'stop_supervise':
      # Use -x to cause supervise to exit once dnscache and multilog exit
      provider => shell,
      cwd      => '/',
      command  => "svc -x -t  ${base_path}/log ${base_path}",
    } -> # and then...
    file { $base_path:
      ensure  => 'absent',
      purge   => true,
      recurse => true,
      force   => true,
    } -> # and then...
    user { 'dnscache':
      ensure => absent,
    }
    cron { 'cron_root_server_reset':
      ensure => absent,
    } -> # and then...
    file { '/usr/bin/set-root-servers':
      ensure => absent,
    }
    if $purge_logs {
      file { '/var/log/dbndns/dnscache':
        ensure  => absent,
        purge   => true,
        recurse => true,
        force   => true,
      }
    }
  }
  else {
    ### Users
    user { 'dnscache':
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
    file { "${base_path}/root/servers":
      ensure => directory,
    }
    file { "${base_path}/root/ip":
      ensure => directory,
    }
    file { "${base_path}/log":
      ensure => directory,
    }
    file { "${base_path}/log/env":
      ensure => directory,
      before => Service[$service_name],
    }
    file { '/var/log/dbndns/dnscache':
      ensure => directory,
      owner  => 'dnslog',
      group  => 'nogroup',
      before => Service[$service_name],
    }
    file { "${base_path}/log/main":
      ensure => link,
      target => '/var/log/dbndns/dnscache',
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
      source  => 'puppet:///modules/dbndns/run-dnscache',
      require => File["${base_path}/log/run"]
    }
    ### Extra files
    file { "${base_path}/seed":
      ensure  => file,
      mode    => '0600',
      owner   => 'root',
      group   => 'root',
      replace => false,
      notify  => Exec['populate_seed'],
      before  => Service[$service_name],
    }
    exec { 'populate_seed':
      provider    => shell,
      cwd         => $base_path,
      command     => 'dd if=/dev/urandom count=1 bs=128 > seed',
      refreshonly => true,
    }
    file { "${base_path}/log/status":
      ensure => file,
      mode   => '0644',
      owner  => 'dnslog',
      group  => 'nogroup',
    }
    ### Env configuration
    file { "${base_path}/env/CACHESIZE":
      ensure  => file,
      content => "${cachesize}",
      notify  => Service[$service_name],
    }
    # Can't use a bare variable due to PUP-1768
    file { "${base_path}/env/DATALIMIT":
      ensure  => file,
      content => "${derived_datalimit}",
      notify  => Service[$service_name],
    }
    file { "${base_path}/env/IP":
      ensure  => file,
      content => "${ip}",
      notify  => Service[$service_name],
    }
    file { "${base_path}/env/IPSEND":
      ensure  => file,
      content => "${derived_ipsend}",
      notify  => Service[$service_name],
    }
    file { "${base_path}/env/ROOT":
      ensure  => file,
      content => "${base_path}/root",
      notify  => Service[$service_name],
    }
    if $hidettl {
      file { "${base_path}/env/HIDETTL":
        ensure  => file,
        content => "${hidettl}",
        notify  => Service[$service_name],
      }
    }
    else {
      file { "${base_path}/env/HIDETTL":
        ensure => absent,
        notify => Service[$service_name],
      }
    }
    ### Logging env configuration
    file { "${base_path}/log/env/LOGSIZE":
      ensure  => file,
      content => "${log_size}",
      notify  => Exec['restart_dnscache_multilog'],
    }
    # Can't use a bare variable due to PUP-1768
    file { "${base_path}/log/env/LOGNUM":
      ensure  => file,
      content => "${log_num}",
      notify  => Exec['restart_dnscache_multilog'],
    }
    file { "${base_path}/log/env/FLAGS":
      ensure  => file,
      content => "${log_flags}",
      notify  => Exec['restart_dnscache_multilog'],
    }
    file { "${base_path}/log/env/LOGROOT":
      ensure  => file,
      content => '/var/log/dbndns/dnscache',
      notify  => Exec['restart_dnscache_multilog'],
    }
    # Artificial restart for multilog, as it's usually automatically
    # run by it's parent service.
    exec { 'restart_dnscache_multilog':
      cwd         => "${base_path}/log/",
      command     => '/usr/bin/svc -t .',
      refreshonly => true,
      require     => Service[$service_name],
    }
    ### Base access control
    # Always permit localhost access to the cache
    dbndns::cache_access {'127.0.0.1':}

    ### Upstream servers
    if $forwardonly {
      file { "${base_path}/env/FORWARDONLY":
        ensure  => file,
        content => "1",
      } -> # and then...
      file { "${base_path}/root/servers/@":
        ensure  => file,
        content => join($forwardonly, "\n"),
        notify  => Service[$service_name],
      }
    }
    else{
      # Fire the root server script one time to set the root servers
      file { "${base_path}/env/FORWARDONLY":
        ensure => absent,
      } ~> # and then bootstrap using /etc/dnsroots.global
      file { "${base_path}/root/servers/@":
        ensure => file,
        source => $dbndns::params::dnsroots_path,
        notify => Service[$service_name],
      }
    }
    ### Service control
    service { $service_name:
      ensure   => $ensure,
      provider => 'daemontools',
      # we need all of these resources to exist before we start
      # the service; trigger deferal was being wierd.
      require  => [File["${base_path}/env/CACHESIZE"],
                  File["${base_path}/env/DATALIMIT"],
                  File["${base_path}/env/IP"],
                  File["${base_path}/env/IPSEND"],
                  File["${base_path}/env/ROOT"],
                  File["${base_path}/env/HIDETTL"],
                  File["${base_path}/env/FORWARDONLY"]
                  ],
    }
    ### Root server list generator
    file { '/usr/bin/set-root-servers':
      ensure => file,
      mode   => '0755',
      source => 'puppet:///modules/dbndns/set-root-servers',
    }
    cron { 'cron_root_server_reset':
      command => '/usr/bin/set-root-servers',
      month   => [5, 11],
    }
  }
}
