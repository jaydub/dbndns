# Type: dnbdns::tinydns_entry
#
# Generic tinydns dns entry type. This resource is a thin wrapper that produces
# tinydns data formatted entries, and so reflects that syntax.
#
# data format is colon separated, in the form:
#
# special character indicating type
# fqdn
# one or more data fields
# ttl - in seconds. Minimum 2. many clients treat less than 300 as 300.
#      Dnscache treats times over a week as a week.
# timestamp - time to die if ttl = 0, time to start otherwise.
#           timestamps with timezones are convere to TAI64 format.
# loc - a one to two letter ascii code defined by % lines.
#
# . NS, A, SOA (multiple can be defined, only one SOA is created)
# & NS, A
# Z SOA (rarely used)
# = A, PTR
# + A (use this instead of CNAMES)
# @ MX, A (Similar rules as for '.')
# ' TXT : must be escaped as octal \072 (what else?)
# ^ PTR (rarely needed)
# C CNAME (probably not necessary for a puppet managed system.
# : generic form. We should add special types for RR
# 6 AAAA
#
#
# Another type for records not directly supported, which acts as a more
# substantial abstraction around the generic record type
#
# A final type mimicing the hosts type allowing the creation onf a = and
# + records from a list of aliases. TTL and timestamp expected to apply to
# the lot.

define dbndns::tinydns_entry (
  $data,                  # array of values, depending on the record type.
  $type      = '',        # derived from the resource title if omitted
  $fqdn      = '',        # derived from the resource title if omitted
  $ttl       = '',        # use tinydns default
  $timestamp = '',        # use no timestamp
  $loc       = '',        # use no location
  $ensure    = 'present', # or absent
  $purge     = $dbndns::tinydns::purge
)
{
  $name_re = '^([.&=+@%\'CZ\:6])([*a-zA-Z0-9\-\.]+)'
  $ip_prefix_re = '[0-9\.]+'
  $loc_re = '^[a-zA-Z]{1,2}$'

  if $purge or $ensure == 'absent'{
    if $purge == false {
      concat::fragment { "${title}_dns_entry":
        ensure => absent,
        target => 'dnsdata',
        notify => Exec['data.cbd'],
      }
    }
  }
  else {
    if $type == '' or $fqdn == '' {
      validate_re(
        $name, $name_re,
        'title must be of the form {type}{fqdn} if type or fqdn are not set'
      )
      if $type == '' {
        $type_act = regsubst($name, $name_re, '\1')
      }
      else {
        $type_act = $type
      }
      if $fqdn == '' {
        $fqdn_act = regsubst($name, $name_re, '\2')
      }
      else {
        $fqdn_act = $fqdn
      }
    }

    # Check FQDN
    if $type_act != '%' {
      unless is_domain_name($fqdn_act) {
        fail('fqdn must be a valid domain name')
      }
    }
    else {
      validate_re($fqdn_act, $loc_re,
      'loc names must be a sequence of one or two ASCII letters.')
    }

    # Data is always an array, even if it's just one value.
    validate_array($data)

    # Turn data into rdata by type
    case $type_act {
      '.', '&': {
        # Primary and child name server
        unless is_ip_address($data[0]) {
          fail('first data field must be an IP address')
        }
        unless is_domain_name($data[1]) {
          fail('host name must be a valid domain name')
        }
        $rdata = "${data[0]}:${data[1]}"
      }
      '=', '+': {
        # Primary and alias addresses
        unless is_ip_address($data[0]) {
          fail('first data field must be an IP address')
        }
        $rdata = "${data[0]}"
      }
      '@' : {
        # MX records
        unless is_ip_address($data[0]) {
          fail('first data field must be an IP address')
        }
        unless is_domain_name($data[1]) {
          fail('host name must be a valid domain name')
        }
        unless is_integer($data[2]) {
          fail('distance must be an integer')
        }
        $rdata = "${data[0]}:${data[1]}:${data[2]}"
      }
      '%': {
        # A location declaration.
        validate_re($data[0], ip_prefix_re, 'Needs a valid IP prefix')
        $rdata = "${data[0]}"
      }
      '^', 'C': {
        unless is_domain_name($data[0]) {
          fail('host name must be a valid domain name')
        }
        $rdata = "${data[0]}"
      }
      'Z': {
        # SOA record. primary domain server, contact address,
        # serial number, refresh time, retry time, expiry time, minimum time.
      }
      '\'': {
        # TXT.
        # String, which must be escaped with octal codes to include
        # arbitrary bytes. Unclear if UTF-8?
      }
      ':': {
        # Generic record generator. n is the integer number of the record type,
        # while rdata depends on n.
      }
      default: { fail('Unrecogniszed tinydns record type') }
    }

    unless $ttl == '' {
      unless is_numeric($ttl) {
        fail('ttl must be a number, or an empty string')
      }
    }
    if $timestamp == '' {
      $tai64 = ''
    }
    else {
      $tai64 = to_tinydns_tai64($timestamp)
    }
    unless $loc == '' {
      validate_re($loc, $loc_re,
      'locs must be a sequence of one or two ASCII letters.')
    }
    concat::fragment { "${title}_dns_entry":
      target  => 'dnsdata',
      content => "${type_act}${fqdn_act}:${rdata}:${ttl}:${tai64}:${loc}\n",
      notify  => Exec['data.cdb'],
    }
  }
}
