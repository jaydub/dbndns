# Type: dnbdns::tinydns_host
#
# Creates name to IP mappings and aliases, with an interface similar to
# the Host type.
#
# can't use the resource title if you're also using several locations, or
# start/end times

define dbndns::tinydns_host (
  $ip,
  $fqdn               = '',    # derived from the resource title if absent
  $ensure             = 'present', # or 'absent'
  $fqdn_aliases       = [],
  $timestamp_to_start = '',
  $timestamp_to_end   = '',
  $loc                = '',
  $purge              = $dbndns::tinydns::purge
)
{
  $name_re = '^([.&=+@%\'CZ\:6])([*a-zA-Z0-9\-\.]+)'
  $ip_prefix_re = '[0-9\.]+'
  $loc_re = '^[a-zA-Z]{1,2}$'

  if $purge or $ensure == 'absent'{
    if $purge == false {
      concat::fragment { "${title}_host_entry":
        ensure => absent,
        target => 'dnsdata',
        notify => Exec['data.cbd'],
      }
    }
  }
  else {
    if $fqdn == '' {
      # Work around for frozen strings from heira breaking is_domain_name.
      # TODO file bug.
      $fqdn_act = "${title}"
    }
    else {
      $fqdn_act = $fqdn
    }
    # Check FQDN
    unless is_domain_name($fqdn_act) {
        fail("fqdn ${fqdn_act} must be a valid domain name")
    }

    # aliases should always be an array, even if it's just one value.
    # but, for some reason, something keeps flattening them into a single
    # string. Fixing that.
    if is_string($fqdn_aliases) {
      $fqdn_aliases_array = [$fqdn_aliases]
    } else {
      $fqdn_aliases_array = $fqdn_aliases
    }
    # No iteration in the manifests without future parser, so
    # we check domain names in the template.

    # check IP.
    # TODO. Do the right thing for v4/v6 addresses.
    unless is_ip_address($ip) {
      fail('ip must be a valid IPv4 address')
    }

    # Only one timestamp
    if $timestamp_to_start != '' and $timestamp_to_end != '' {
      fail('you cannot set a \'start\' and \'stop\' time on the same entry!')
    }

    # Convert timestamps from human readable to TAI64
    if $timestamp_to_start == '' {
      if $timestamp_to_end == '' {
        $tai64 = ''
      }
      else {
        $tai64 = to_tinydns_tai64($timestamp_to_end)
      }
    }
    else {
      $tai64 = to_tinydns_tai64($timestamp_to_start)
    }

    # Set an appropriate TTL
    if $timestamp_to_end != '' {
      $ttl = 0
    }
    else {
      $ttl = ''
    }

    # Check location
    unless $loc == '' {
      validate_re($loc, $loc_re,
      'locs must be a sequence of one or two ASCII letters.')
    }

    # Assembly into tinydns data records!
    concat::fragment { "${title}_fqdn_entry":
      target  => 'dnsdata',
      content => template('dbndns/tinydns_host.erb'),
      notify  => Exec['data.cdb'],
    }
  }
}
