# Type: dbndns::tinydns_host_factory
#
# A factory class that pulls data from the dbndns::tinydns_host_entries
# key in hiera, and  uses it to create a set of
# dbndns::tinydns_host resources.
#
# Parameters:
#  hiera_key - the key that the hiera look up will use to find your
#    tinydns_host settings. Defaults to dbndns::tinydns_host_entries
#  resource_type - the resource to instansiate based on that data. Defaults
#    to dbndns::tinydns_host
#  resource_creation - one of default, virtual or export, corresponding to
#    those particular kinds of resource creation methods. Defaults to
#    'default'
#
class dbndns::tinydns_host_factory
(
  $hiera_key = 'dbndns::tinydns_host_entries',
  $resource_type = 'dbndns::tinydns_host',
  $resource_creation = 'default'
)
{
  case $resource_creation {
    'export':  { $qualified_resource_type = "@@${resource_type}" }
    'virtual': { $qualified_resource_type = "@${resource_type}" }
    default:   { $qualified_resource_type = $resource_type }
  }
  create_resources($qualified_resource_type, hiera($hiera_key, {}))
}
