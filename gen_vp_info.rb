require 'set'

require_relative 'config.rb'
require_relative 'retrieve_data.rb'
require_relative 'lib/asmapper.rb'

include TopoConfig

if $0  == __FILE__
    startdate = Date.parse('20150219')
    duration = 7

    numday = 0
    vplist = Set.new
    #output = "data/iplane_vps.txt"
    output = "data/yahoo_vps.txt"
    fout = File.open(output, 'w')

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1
        #tracelist = retrieve_iplane(date)
        tracelist = retrieve_yahoo(date)
        tracelist.each do |vp, _|
            #next if IPLANE_BLACKLIST.include?(vp)
            next if vplist.include?(vp)

            vp_ip = ASMapper.get_ip_from_url(vp)
            vp_asn = ASMapper.query_asn(vp_ip)
            fout.puts "#{vp} #{vp_ip} #{vp_asn}"
        end
    end
    fout.close
    puts "Output to #{output}"
end
