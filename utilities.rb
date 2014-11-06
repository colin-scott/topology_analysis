#!/usr/bin/env ruby

#require 'inline'

class Method
    alias_method :old_to_s, :to_s unless self.instance_methods.include? :old_to_s

    def to_s
        str = old_to_s

        # "#<Method: String#count>"
        return str.gsub(/#<Method: /, '').gsub(/>$/, '').split("#")[1]
    end
end

class Object
   def deep_copy( object )
     Marshal.load( Marshal.dump( object ) )
   end
end

class Hash
    def map_values()
        new_hash = {}
        self.each do |k,v|
            new_hash[k] = yield v
        end
        new_hash
    end

    def value_set()
        values = self.values
        values.each { |elt| raise "not a list! #{elt}" if !elt.is_a?(Array) and !elt.is_a?(Set) }
        return self.values.reduce(Set.new) { |sum,nex| sum | nex }
    end

    def value2keys
        h = Hash.new { |h,k| h[k] = [] }
        self.each do |k,v|
           h[v] << k
        end
        h
    end

    # can also do something like this:
    # def initialize
    #      @map = Hash.new { |hash, key| hash[key] = [] }
    # end
    #
    # def addToList(key, val)
    #      @map[key] << val
    # end
    # for when the keys hash to an array of values
    # add the value to the array, creating a new array when necessary
    def append (key, value )
      if not self.has_key?(key)
        self[key] = Array.new
      end
      self[key] << value
    end
    # for when the keys hash to their own hash
    # create a new hash when necessary (default false)
    # and add the new k/v pair)
    def append_to_hash (key, intermediatekey, value )
      if not self.has_key?(key)
        self[key] = Hash.new(false)
      end
      (self[key])[intermediatekey] = value
    end
    # for when the keys hash to their own hash
    # and each intermediate key hashes to an array of values
    # create a new hash when necessary (default Array.new)
    # and append the new value
    # this may be broken?
    def append2_to_hash (key, intermediatekey, value )
      if not self.has_key?(key)
        self[key] = Hash.new(Array.new)
      end
      self[key].append(intermediatekey,value)
    end

    # could instead do:
    # @h3 = Hash.new{ |h,k| h.has_key?(k) ? h[k] : k }
    # given a key,  return the value if the key is in the hash
    # otherwise return the key
    def getValueOrIdentity( key )
      if self.has_key?(key)
        return self[key]
      else
        return key
      end
    end
end

class Set
    def join(sep=$,)
        self.to_a.join(sep)
    end

    def each()
       self.to_a.each { |elt| yield elt }
    end
end

class Array
    # So that Sets play well with Arrays
    alias_method :old_or, :| unless self.instance_methods.include? :old_plus
    alias_method :old_plus, :+ unless self.instance_methods.include? :old_plus
    alias_method :old_minus, :- unless self.instance_methods.include? :old_minus
    alias_method :old_and, :& unless self.instance_methods.include? :old_and

    def &(other)
        raise "#{other} doesn't respond to &" unless other.respond_to?(:&)
        old_and(other.to_a)
    end

    def -(other)
        raise "#{other} doesn't respond to -" unless other.respond_to?(:-)
        old_minus(other.to_a)
    end

    def +(other)
        raise "#{other} doesn't respond to +" unless other.respond_to?(:+)
        old_plus(other.to_a)
    end

    def |(other)
        raise "#{other} doesn't respond to |" unless other.respond_to?(:|)
        old_or(other.to_a)
    end

    # convert to a hash
    # if given a param, assigns that value to everything
    # else yields each value to the block
    # note that:
    # a) it does not give a real default to the hash
    # b) you cannot give nil as the default value
    def to_h(default=nil)
      inject({}) {|h,value| h[value] = default || yield(value); h }
    end

    def custom_to_hash()
        hash = {}
        self.each do |elt|
            raise "not a pair! #{elt.inspect}" if elt.size != 2
            hash[elt[0]] = elt[1]
        end

        hash
    end

    # given a hash from elt -> category, iterates over all elements of array and returns a new
    # hash from category -> [list of elts in the category]
    #
    # takes an optional second argument -> the category to assign to unknown
    # elts
    # else, ignores elts that don't have a category
    #
    # Example Usage:
    # ips.categorize(FailureIsolation.IPToPoPMapping, DataSets::Unknown)
    def categorize(elt2category, unknown=nil)
        categories = Hash.new { |h,k| h[k] = [] }
        self.each do |elt|
           if elt2category.include? elt
                categories[elt2category[elt]] << elt
           elsif unknown
                categories[unknown] << elt
           end
        end
        categories
    end

    # Given the name of a method or object field, categorize this Array as in
    # Array#categorize(), where all elements with the same method or field
    # value are put into the same category.
    #
    # Example usage:
    # outages.categorize_on_attr("dst")
    # # -> returns a hash from outage destination -> [list of outages with
    # that destination]
    def categorize_on_attr(send_name)
        categories = Hash.new { |h,k| h[k] = [] }
        self.each do |elt|
            if !elt.respond_to?(send_name)
                raise "elt #{elt} doesn't respond to #{send_name}"
            else
                categories[elt.send(send_name)] << elt
            end
        end
        categories
    end

    # field is the method to issue a send to
    def binary_search(elem, field=nil, low=0, high=self.length-1)
      mid = low+((high-low)/2).to_i
      if low > high
        return -(low + 1)
      end
      mid_elt = (field.nil?) ? self[mid] : self[mid].send(field)
      if elem < mid_elt
        return binary_search(elem, field, low, mid-1)
      elsif elem > mid_elt
        return binary_search(elem, field, mid+1, high)
      else
        return mid
      end
    end

    def sorted?(field=nil)
        return true if self.empty?

        if field.nil?
            last = self[0]
        else
            last = self[0].send(field)
        end

        self[1..-1].each do |elt|
            curr = (field.nil?) ? elt : elt.send(field)
            return false if curr < last
            last = curr
        end

        return true
    end

    def mode()
        counts = Hash.new(0)
        self.each { |elt| counts[elt] += 1 }
        return nil if counts.empty?
        max_val = counts[self[0]]
        max_key = self[0]

        counts.each do |elt,count|
            if count > max_val
                max_val = count
                max_key = elt
            end
        end
        max_key
    end
end

class String
    def matches_ip?()
        return self =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/
    end
end

module Inet
  ## Let's make Ruby's bit fiddling reasonably fast!
  #inline(:C) do |builder|
  #     builder.include "<sys/types.h>"
  #     builder.include "<sys/socket.h>"
  #     builder.include "<netinet/in.h>"
  #     builder.include "<arpa/inet.h>"

  #     builder.prefix %{

  #     // 10.0.0.0/8
  #     #define lower10 167772160
  #     #define upper10 184549375
  #     // 172.16.0.0/12
  #     #define lower172 2886729728
  #     #define upper172 2887778303
  #     // 192.168.0.0/16
  #     #define lower192 3232235520
  #     #define upper192 3232301055
  #     // 224.0.0.0/4
  #     #define lowerMulti 3758096384
  #     #define upperMulti 4026531839
  #     // 127.0.0.0/16
  #     #define lowerLoop 2130706432
  #     #define upperLoop 2147483647
  #     // 169.254.0.0/16 (DHCP)
  #     #define lower169 2851995648
  #     #define upper169 2852061183
  #     // 0.0.0.0
  #     #define zero 0

  #     }

  #     builder.c_singleton %{

  #     // can't call ntoa() directly
  #     char *ntoa(unsigned int addr) {
  #         struct in_addr in;
  #         in.s_addr = addr;
  #         return inet_ntoa(in);
  #      }

  #      }

  #     builder.c_singleton %{

  #     // can't call aton() directly
  #     unsigned int aton(const char *addr) {
  #         struct in_addr in;
  #         inet_aton(addr, &in);
  #         return in.s_addr;
  #      }

  #      }

  #      builder.c_singleton %{

  #      int in_private_prefix(const char *addr) {
  #          // can't call aton() apparently?
  #          // so we'll just be redundant
  #          struct in_addr in;
  #          inet_aton(addr, &in);
  #          unsigned int ip = in.s_addr;

  #          if( (ip > lower10 && ip < upper10 ) || (ip > lower172 && ip < upper172)
  #                          || (ip > lower192 && ip < upper192) ||
  #                          (ip > lowerMulti && ip < upperMulti) ||
  #                          (ip > lowerLoop && ip < upperLoop) ||
  #                          (ip > lower169 && ip < lower169) ||
  #                          (ip == zero)) {
  #              return 1;
  #          } else {
  #              return 0;
  #          }
  #       }
  #     }
  #end
  #def Inet::in_private_prefix?(addr)
  #    Inet::in_private_prefix(addr) == 1;
  #end


  $PRIVATE_PREFIXES=[["192.168.0.0",16], ["10.0.0.0",8], ["127.0.0.0",8], ["172.16.0.0",12], ["169.254.0.0",16], ["224.0.0.0",4], ["0.0.0.0",8]]

  def Inet::ntoa( intaddr )
    ((intaddr >> 24) & 255).to_s + '.' + ((intaddr >> 16) & 255).to_s + '.'  + ((intaddr >> 8) & 255).to_s + '.' + (intaddr & 255).to_s
  end

  def Inet::aton(dotted)
    if /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})?$/.match(dotted)==nil then return 0 end
    ints=dotted.chomp("\n").split(".").collect{|x| x.to_i}
    val=0
    ints.each{|n| val=(val*256)+n}
    return val
  end

  def Inet::prefix(ip,length)
    ip=Inet::aton(ip) if  ip.is_a?(String) and ip.include?(".")
    return ((ip>>(32-length))<<(32-length))
  end

  def Inet::in_private_prefix?(ip)
    ip=Inet::aton(ip) if  ip.is_a?(String) and ip.include?(".")
    $PRIVATE_PREFIXES.each do |prefix|
      return true if Inet::aton(prefix.at(0))==Inet::prefix(ip,prefix.at(1))
    end
    return false
  end

  def Inet::prefix(ip,length)
    ip=Inet::aton(ip) if  ip.is_a?(String) and ip.include?(".")
    return ((ip>>(32-length))<<(32-length))
  end


  $blacklisted_prefixes=nil
  def Inet::in_blacklisted_prefix?(ip)
    ip=Inet::aton(ip) if  ip.is_a?(String) and ip.include?(".")
    if $blacklisted_prefixes.nil?
      $blacklisted_prefixes = []
      File.open($BLACKLIST,"r").each do |line|
        prefix=line.chomp.split("/")
        $blacklisted_prefixes << [Inet::aton(prefix.at(0)),prefix.at(1).to_i]
      end
    end
    $blacklisted_prefixes.each{|prefix|
      return true if prefix.at(0)==Inet::prefix(ip,prefix.at(1))
    }
    return false
  end
end

# removes blacklisted and private addresses from set of measurement targets
def inspect_targets(targets_orig,privates_orig,blacklisted_orig, logger=$LOG)
  targets,privates,blacklisted=targets_orig.clone,privates_orig.clone,blacklisted_orig.clone
  raise "#{targets.class} not an Array!\n #{targets_orig.class}\n #{targets_orig.inspect}\n #{targets.inspect}" if !targets.respond_to?(:delete_if)
  targets.delete_if {|target|
    # to handle cases like timestamp when the request is actually an array
    # we assume the first is the destination and do not blacklist based on
    # the other values
    if target.class==Array
      target=target.at(0)
    end
    privates.include?(target) or blacklisted.include?(target) or
    if Inet::in_private_prefix?(target)
      privates << target
      logger.puts "Removed private address #{target} from targets"
      true
    elsif Inet::in_blacklisted_prefix?(target)
      blacklisted << target
      logger.puts "Removed blacklisted address #{target} from targets"
      true
    else
      false
    end
  }
  return targets, privates, blacklisted
end

# take data, a string read in from an iplane-format binary trace.out file
# return an array of traceroutes, where each is [dst,hops array, rtts array,
# ttls array]
# will throw TruncatedTraceFileException for malformed files
# if you give it print=true AND a block, will yield the print string to the
# block, so you can for instance give it the source
def convert_binary_traceroutes(data, print=false)
  offset=0
  traceroutes=[]
  while not offset>=data.length
    header=data[offset,16].unpack("L4")
    offset += 16
    if header.nil? or header.include?(nil)
      raise TruncatedTraceFileException.new(traceroutes), "Error reading header", caller
    end
    client_id=header.at(0)
    uid=header.at(1)
    num_tr=header.at(2)
    record_length=header.at(3)
    (0...num_tr).each{|traceroute_index|
      tr_header=data[offset,8].unpack("NL")
      offset += 8
      if tr_header.nil? or tr_header.include?(nil)
        raise TruncatedTraceFileException.new(traceroutes), "Error reading TR header", caller
      end
      dst=Inet::ntoa(tr_header.at(0))
      numhops=tr_header.at(1)
      hops = []
      rtts = []
      ttls = []
      last_nonzero=-1
      (0...numhops).each{|j|
        hop_info=data[offset,12].unpack("NfL")
        offset += 12
        if hop_info.nil? or hop_info.include?(nil)
          raise TruncatedTraceFileException.new(traceroutes), "Error reading hop", caller
        end
        ip = Inet::ntoa(hop_info.at(0))
        rtt = hop_info.at(1)
        ttl = hop_info.at(2)
        if (ttl > 512)
          raise TruncatedTraceFileException.new(traceroutes), "TTL>512, may be corrupted", caller
        end
        if ip!="0.0.0.0"
          last_nonzero=j
        end
        hops << ip
        rtts << rtt
        ttls << ttl

      }
      if last_nonzero>-1
        traceroutes << [dst,hops,rtts,ttls]
        if print
          tr_s="#{dst} #{last_nonzero+1} #{hops[0..last_nonzero].join(" ")}"
          if block_given?
            yield(tr_s)
          else
            $stdout.puts "tr_s"
          end
          #puts "#{ARGV[1..-1].join(" ")} #{dst} #{last_nonzero+1} #{hops[0..last_nonzero].join(" ")}"
        end
      end

    }
  end
  return traceroutes
end

##$ip2cluster = Hash.new{ |h,k| h.has_key?(k) ? h[k] : ( h.has_key?(k.split(".")[0..2].join(".") + ".0/24") h[k.split(".")[0..2].join(".") + ".0/24"] : k.split(".")[0..2].join(".") + ".0/24") }
#$ip2cluster = Hash.new{ |h,k| h.has_key?(k) ? h[k] : k }
#$cluster2ips = Hash.new(Array.new)
#def loadClusters(clsfn)
#  File.open( clsfn, "r" ){|f|
#    linenum=1
#    f.each_line{|line|
#      info = line.chomp("\n").split(" ")
#      # cluster=linenum
#      cluster=info.at(0)
#      $cluster2ips[cluster] = info
#      info.each{|ip|
#        $ip2cluster[ip] = cluster
#        # $cluster2ips.append( info.at(0), ip )
#      }
#      linenum+=1
#    }
#  }
#end

## mappings for PL nodes: hostname to IP and back
## some VPs, especially mlab ones, have more than one IP address
## if the $PL_HOSTNAMES_W_IPS includes double entries for these, we map from
## all IPs to the hostname, but we map from the hostname only to the first IP
## in the file
#if $pl_ip2host.nil? then $pl_ip2host = Hash.new{ |h,k| (k.respond_to?(:downcase) && h.has_key?(k.downcase)) ? h[k.downcase] : k } end
#if $pl_host2ip.nil? then
#    $pl_host2ip = Hash.new do |h,k|
#        result = nil
#        if (k.respond_to?(:downcase) && h.has_key?(k.downcase))
#            result =h[k.downcase]
#        end
#
#        result
#    end
#end
#def loadPLHostnames
#  File.open( $PL_HOSTNAMES_W_IPS.chomp("\n"), "r"){|f|
#    f.each_line{|line|
#      info = line.chomp("\n").split(" ")
#      next if info.empty? or !info[1].respond_to?(:downcase) or !info[0].respond_to?(:downcase)
#      if info.at(0).include?(",")
#          info[0] = info.at(0).split(",").at(0)
#      end
#      $pl_ip2host[ info.at(1).downcase ] = info.at(0)
#      next if $pl_host2ip.has_key?(info.at(0)) # skip duplicate hostnames
#      $pl_host2ip[ info.at(0).downcase ] = info.at(1)
#    }
#  }
#end
#
## mappings from PL hostname to site; can be used to check if 2 are at the same
## site in order to exclude probes from the target site, say
#$pl_host2site = Hash.new{ |h,k| (k.respond_to?(:downcase) && h.has_key?(k.downcase)) ? h[k.downcase] : k }
#
#def loadPLSites
#  File.open( $PL_HOSTNAMES_W_SITES.chomp("\n"),"r"){|f|
#    f.each_line{|line|
#      info = line.chomp("\n").split(" ")
#      next if info[0].nil?
#      $pl_host2site[ info.at(0).downcase ] = info.at(1)
#    }
#  }
#end
#
## set of PL spoofers
#$spoofers=Array.new
#def loadSpoofers(fn)
#  File.open(fn.chomp("\n"),"r"){|f|
#    f.each_line{|line|
#      $spoofers << line.chomp("\n")
#    }
#  }
#end
#
## set of PL ts spoofer sites
#$ts_spoofer_sites=Array.new
#def loadTSSpoofers(fn,is_hosts=true)
#  File.open(fn.chomp("\n"),"r"){|f|
#    f.each_line{|line|
#      if is_hosts
#        $ts_spoofer_sites << $pl_host2site[line.chomp("\n")]
#      else
#        $ts_spoofer_sites << line.chomp("\n")
#      end
#    }
#  }
#end

if $0 == __FILE__
    puts Inet::prefix("1.2.3.4", 4)
    puts Inet::ntoa(Inet::aton("1.2.3.4"))
    puts Inet::in_private_prefix?("1.2.3.4")
    puts Inet::in_private_prefix?("192.168.1.1")
    puts Inet::in_private_prefix?("0.0.0.0")
end
