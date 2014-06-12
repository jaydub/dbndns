# class dbndns::users
#
# dbndns doesn't add any users that the components should run as. This
# class creates the ones used in common by the components.

class dbndns::users ($purge=false) {
  if $purge {
    user { 'dnslog':
      ensure   => absent,
    }
  }
  else {
    # Create the dnslog user
    user { 'dnslog':
      ensure   => present,
      gid      => 'nogroup',
      home     => '/var/log',
      shell    => '/bin/false',
      password => '*',
      system   => true,
    }
  }
}
