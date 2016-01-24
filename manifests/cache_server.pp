# Type: dbndns::cache_server
#
# Creates an entry in root/servers mapping some domain to a set of name
# servers. Use this to resolve local machine names in some local domain via
# your own tinydns instance.
#
# Don't replace the top level '@' listing with this; instead, set that via
# forwardonly on dbndns::dnscache to upstream resolvers, or let the module
# set the root servers.
#
# Parameters:
#   domain - the domain that the servers are authoritative for.
#   servers - the list of servers to resolve to
#   enable - if true, the setting is created, if false, removed. Set
#     enable=false *before* removing the line in your manifests!
#   purge - drops the entry much like enable=false, but doesn't notify
#     the service to restart. Used in conjuction with dbndns::dnscache's
#     purge setting, it shares it's default

define dbndns::cache_server (
  $domain=$name,
  $servers=[],
  $enable=true,
  $purge=$dbndns::dnscache::purge)
{
  if $purge {
    file { "${dbndns::dnscache::base_path}/root/servers/${domain}":
      ensure  => absent,
    }
  }
  else {
    if $enable {
      validate_array($servers)
      if !empty($servers) {
        file { "${dbndns::dnscache::base_path}/root/servers/${domain}":
          ensure  => file,
          mode    => '0644',
          content => join($servers, "\n"),
          notify  => Service[$dbndns::dnscache::service_name],
        }
      }
    }
    else {
      file { "${dbndns::dnscache::base_path}/root/servers/${domain}":
        ensure => absent,
        notify => Service[$dbndns::dnscache::service_name],
      }
    }
  }
}
