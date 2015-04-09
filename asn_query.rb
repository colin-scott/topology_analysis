require_relative "lib/asmapper.rb"
require_relative "lib/utilities.rb"

if $0 == __FILE__
    if ARGV.size == 0
        puts "#{__FILE__} ip_addr"
        exit
    end
    ip = ARGV[0]
    if Inet::in_private_prefix_q? ip
        puts "#{ip} is a private IP address"
    else 
        asn = ASMapper.query_asn ip
        if asn.nil?
            puts "ASN not found."
        else
            puts asn
        end
    end
end
