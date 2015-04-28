require 'set'

require_relative 'config.rb'
require_relative 'retrieve_data.rb'
require_relative 'lib/asmapper.rb'

include TopoConfig

if $0  == __FILE__
    if ARGV.size < 3
        puts "%s platform date duration" % __FILE__
        exit
    end

    platform = ARGV[0]
    startdate = Date.parse(ARGV[1])
    duration = ARGV[2].to_i

    if platform != 'yahoo' and platform != 'iplane'
        puts "Wrong platform option: yahoo/iplane"
        exit
    end

    numday = 0
    vplist = Set.new
    output = if platform == 'iplane' then 'data/iplane_vps.txt' else 'data/yahoo_vps.txt' end
    fout = File.open(output, 'w')

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1
        tracelist = if platform == 'iplane' then retrieve_iplane(date) else retrieve_yahoo(date) end
        tracelist.each do |vp, _|
            #next if IPLANE_BLACKLIST.include?(vp)
            next if vplist.include?(vp)
            vplist << vp
            vp_ip = ASMapper.get_ip_from_url(vp)
            vp_asn = ASMapper.query_asn(vp_ip)
            fout.puts "#{vp} #{vp_ip} #{vp_asn}"
        end
    end
    fout.close
    puts "Output to #{output}"
end
