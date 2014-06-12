# Type: dbndns::cache_reverse_server
#
# Behaves much the same as cache_server, except that it takes an IP network,
# which is used to create the correctly named domain for reverse lookups.
#
# Parameters:
#   network - the network that the servers are authoritative for, of the form
#     192.168.1
#   servers - the list of servers to resolve to
#   enable - if true, the setting is created, if false, removed. Set
#     enable=false *before* removing the line in your manifests!
#   purge - drops the entry much like enable=false, but doesn't notify
#     the service to restart. Used in conjuction with dbndns::dnscache's
#     purge setting, it shares it's default

define dbndns::cache_reverse_server (
  $network=$name,
  $servers=[],
  $enable=true,
  $purge=$dbndns::dnscache::purge)
{
  # split and reverse the network name
  $rev_ip = join(reverse(split($network, '[.]')), '.')
  $domain = "${rev_ip}.in-addr.arpa"

  dbndns::cache_server {$domain:
    servers => $servers,
    enable  => $enable,
    purge   => $purge,
  }
}
