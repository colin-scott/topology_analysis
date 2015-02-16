require 'optparse'

require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'

def retrieve(uri, vp, start_date, end_date)
    return if uri.nil?
    url, path = uri.split(':')
    filelist = `ssh #{url} 'ls #{path}'`
    vpfiles = {}
    filelist.split.each do |fn|
        vp_name, time = parse_filename fn
        date = time.strftime("%Y%m%d")
        next if not vp.nil? and vp != vp_name
        next if not start_date.nil? and date < start_date
        next if not end_date.nil? and date > end_date
        vpfiles[vp_name] = [] if not vpfiles.has_key? vp_name
        vpfiles[vp_name] << fn
   end
   vpfiles
end

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:uri] = TopoConfig::REMOTE_DATA_URI
        opts.on("-u", "--uri URI", "URI to the data source") do |uri|
            options[:uri] = uri
        end
        options[:start] = nil
        opts.on("-s", "--start DATE", "Start date to download (If not set, start from oldest") do |start|
            options[:start] = start
        end
        options[:end] = nil
        opts.on("-e", "--end DATE", "End date to download (If not set, end till latest)") do |enddate|
            options[:end] = enddate
        end
        options[:vp] = nil
        opts.on("--vp VP_NAME", "Name of CDN node (If not set, download data for all vps") do |vp|
            options[:vp] = vp.downcase
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    puts options
    summary = retrieve(options[:uri], options[:vp], options[:start], options[:end])
    summary.each { |vp, files| puts "#{vp}:\t#{files.size}" }
end

