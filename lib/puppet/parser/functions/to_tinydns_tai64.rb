#
#  to_tinydns_tai64.rb
#

require 'time'

EPOCH = 2 ** 62
LEAP_SECONDS_AT_EPOCH = 10

module Puppet::Parser::Functions
  newfunction(:to_tinydns_tai64, :type => :rvalue, :doc => <<-EOS
    Converts a date/time string to the tai64 timestamp string used by
    tinydns-data for the time-to-die/starting-time field.
  
    Requires a date string that the Time class can parse, i.e. both
    '2014-03-20 01:14:56+13:00' and '2014-03-20 01:14:56 NZDT' are known 
    to work.
    EOS
  ) do |arguments|

    raise(Puppet::ParseError, "to_tinydns_tai64(): Wrong number of arguments " +
      "given (#{arguments.size} for 1)") if arguments.size < 1

    datetime = arguments[0]
    klass = datetime.class

    unless [String].include?(klass)
      raise(Puppet::ParseError, 'to_tinydns_tai64(): Requires a ' +
        ' datetime string to work with')
    end

    # Probably needs error handling...
    dt = Time.parse(datetime)

    s = '%016x'
    sec = dt.to_i + LEAP_SECONDS_AT_EPOCH
    ts = if sec >= 0
           sec + EPOCH
         else
           EPOCH - sec
         end
    return s % [ ts ]
  end
end
