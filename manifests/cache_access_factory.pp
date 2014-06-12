# Type: dbndns::cache_access_factory
#
# A factory class that pulls data from the dbndns::cache_access_entries key in
# hiera, and  uses it to create a set of dbndns::cache_access  resources.
# Parameters:
#  hiera_key - the key that the hiera look up will use to find your
#    cache_server settings. Defaults to dbndns::cache_reverse_server_entries
#  resource_type - the resource to instansiate based on that data. Defaults
#    to dbndns::cache_reverse_server
#  resource_creation - one of default, virtual or export, corresponding to
#    those particular kinds of resource creation methods. Defaults to 'default'
#
class dbndns::cache_access_factory
(
  $hiera_key = 'dbndns::cache_access_entries',
  $resource_type = 'dbndns::cache_access',
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
