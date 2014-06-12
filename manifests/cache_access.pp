# Type: dbndns::cache_access
#
# A resource type to represent network ranges that may access a
# dnscache server. Access control changes don't need to restart the
# server to take effect.
#
# Parameters:
#   network - the network that the servers are authoritative for, of the form
#     192.168.1
#   enable - if true, the setting is created, if false, removed. Set
#     enable=false *before* removing the line in your manifests!
#   purge - drops the entry much like enable=false, but it's used in conjuction
#     with dbndns::dnscache's purge setting, it shares it's default

define dbndns::cache_access (
  $network=$name,
  $enable=true,
  $purge=$dbndns::dnscache::purge)
{
  if $purge {
    file { "${dbndns::dnscache::base_path}/root/ip/${network}":
      ensure => absent,
    }
  }
  else {
    if enable {
      file { "${dbndns::dnscache::base_path}/root/ip/${network}":
        ensure => file,
        mode   => '0600',
      }
    }
    else {
      file { "${dbndns::dnscache::base_path}/root/ip/${network}":
        ensure => absent,
      }
    }
  }
}
