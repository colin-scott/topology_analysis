require 'optparse'

require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'

def retrieve_yahoo(date)
    uri = TopoConfig::YAHOO_DATA_URI
    return if uri.nil?
    url, path = uri.split(':')
    filelist = `ssh #{url} 'ls #{path}'`
    vpfiles = {}
    filelist.split.each do |fn|
        vp_name, time = parse_filename fn
        date_ = time.strftime("%Y%m%d")
        next if date != date_
        vpfiles[vp_name] = [] if not vpfiles.has_key? vp_name
        vpfiles[vp_name] << fn
   end
   vpfiles
end

def retrieve_iplane(date)
    year = date[0...4]
    month = date[4...6]
    day = date[6...8]

    uri = TopoConfig::IPLANE_DATA_URI + "#{year}/#{month}/#{day}/"
    html = `curl #{uri}`
    vpfiles = {}
    html.each_line do |line|
        next if not line.start_with? '<li>'
        if line.include? 'trace.out'
            fn = line[line.index('"')+1...line.rindex('"')]
            vp_name = fn.gsub("trace.out.", "").gsub(".gz", "")
            vpfiles[vp_name] = {} if not vpfiles.has_key? vp_name
            vpfiles[vp_name]['trace'] = uri + fn
        elsif line.include? 'index.out'
            fn = line[line.index('"')+1...line.rindex('"')]
            vp_name = fn.gsub("index.out.", "")
            vpfiles[vp_name] = {} if not vpfiles.has_key? vp_name
            vpfiles[vp_name]['index'] = uri + fn
        end
    end
    vpfiles
end

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:backend] = nil
        opts.on("-b", "--backend BACKEND", [:yahoo, :iplane], "Select backend (yahoo, iplane)") do |backend|
            options[:backend] = backend
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
        opts.on("--vp VP_NAME", "Name of CDN node (If not set, download data for all vps (only for yahoo)") do |vp|
            options[:vp] = vp.downcase
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    puts options
    if options[:backend] == :yahoo
        summary = retrieve_yahoo(options[:vp], options[:start], options[:end])
        summary.each { |vp, files| puts "#{vp}:\t#{files.size}" }
    elsif options[:backend] == :iplane
        filelist = retrieve_iplane(options[:start])
        filelist.each { |vp, uri| puts "#{vp}:\t#{uri}" }
    end
end
