require 'socket'

module ASMapper
    MAX_CACHE_SIZE = 10000
    @cache = Hash.new

    def self.query_as_num ip
        if @cache.has_key? ip
            asn = @cache[ip]
        else
            socks = TCPSocket.new "127.0.0.1", 5100
            asn = nil
            counter = 0
            begin
                socks.puts "#{ip} 0"
                asn = socks.gets.strip
                socks.close
            rescue Errno::EPIPE
                socks.close
                socks = TCPSocket.new "127.0.0.1", 5100
                counter += 1
                retry if counter < 3
            end
            asn = nil if asn.empty?
            # direct clear cache if hits the limit
            @cache.clear if @cache.size == MAX_CACHE_SIZE
=begin
            if @cache.size == MAX_CACHE
                # evict the oldest query
                evict = nil
                min = nil
                @cache.each do |key, val|
                    if min.nil? or val[1] < min
                        min = val[1]
                        evict = key
                    end
                end
                @cache.delete(evict)
            end
=end
            @cache[ip] = asn
        end
        # it might be "4808_23724_37958"
        # so don't conver it into integer
        asn
    end
end

if $0 == __FILE__
    puts ASMapper.query_as_num "8.8.8.8"
    puts ASMapper.query_as_num "8.8.4.4"
end
