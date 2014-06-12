# class dbndns:packages
#
# Installs dbndns and daemontools, and ensures svscan is running. From
# here, tinydns and dnscache can be set up.

class dbndns::packages ($purge=false) {
  if $purge {
    service{'svscan':
      ensure  => stopped,
      before  => Package['daemontools-run'],
    }
    package{'dbndns':
      ensure => purged,
    }
    package{'daemontools':
      ensure => purged,
    }
    # Provides /etc/services and the svscanboot upstart job.
    package{'daemontools-run':
      ensure => purged,
    }
  }
  else {
    package{'dbndns':
      ensure => installed,
    }
    package{'daemontools':
      ensure => installed,
    }
    # Provides /etc/services and the svscanboot upstart job.
    package{'daemontools-run':
      ensure  => installed,
      require => Package['daemontools'],
    }
    # makes sure the Upstart process that runs svscanboot is running.
    # we can use the native daemontools support in puppet from there.
    service{'svscan':
      ensure  => running,
      enable  => true,
      require => Package['daemontools-run'],
    }
  }
}
