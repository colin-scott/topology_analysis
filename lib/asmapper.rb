require 'socket'

require_relative 'cache.rb'

module ASMapper
    @cache = Cache.new

    def self.extract_asn asn
        # to make cache not caching nil, we use 0 to indicate nil
        return 0 if asn.empty?
        asn = asn.chomp
        asn = asn[0...asn.index('_')] if asn.include? '_'
        asn = asn[1...-1] if asn[0] == '{'
        asn = asn[0...asn.index(',')] if asn.include? ','
        if asn.include? '.'
            x, y = asn.split '.'
            asn = (x.to_i << 16) + y.to_i
        end
        return asn.to_i
    end

    def self.query_as_num ip
        asn = @cache.query ip
        if asn.nil?
            socks = TCPSocket.new "127.0.0.1", 5100
            counter = 0
            begin
                socks.puts "#{ip} 0"
                ret = socks.gets.strip
                socks.close
            rescue Errno::EPIPE
                socks.close
                socks = TCPSocket.new "127.0.0.1", 5100
                counter += 1
                retry if counter < 3
            end
            asn = self.extract_asn ret
            @cache.add ip, asn
        end
        # replace 0 by nil
        asn = nil if asn == 0
        asn
    end
end

if $0 == __FILE__
    include ASMapper
    puts extract_asn "7382_8058"
    puts extract_asn "202112_3.5504"
    puts extract_asn "3.5504_202112"
    puts extract_asn "{20013,26512}"
    puts extract_asn "9729_{64664,64665,64666,64667}"
    puts extract_asn "{64664,64665,64666,64667}_9729"

    puts ASMapper.query_as_num "8.8.8.8"
    puts ASMapper.query_as_num "8.8.4.4"
end
