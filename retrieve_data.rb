require 'optparse'

require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/astrace.rb'

include TopoConfig

def retrieve_yahoo(date)
    uri = YAHOO_DATA_URI
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

def download_yahoo_data(filelist)
    filelist.each do |fn|
        localfn = File.join(YAHOO_DATA_DIR, fn)
        localfn_ = localfn.gsub(".gz", "")
        next if File.exist? localfn or File.exist? localfn_
        remote_uri = YAHOO_DATA_URI + fn
        puts "[#{Time.now}] Downloading #{fn}"
        `scp #{remote_uri} #{YAHOO_DATA_DIR}`
    end
    filelist.map! { |fn| fn = File.join(YAHOO_DATA_DIR, fn) }
    return filelist
end

def retrieve_iplane(date)
    year = date[0...4]
    month = date[4...6]
    day = date[6...8]

    uri = IPLANE_DATA_URI + "#{year}/#{month}/#{day}/"
    html = `curl #{uri}`
    vpfiles = {}
    html.each_line do |line|
        next if not line.start_with? '<li>'
        if line.include? 'trace.out'
            fn = line[line.index('"')+1...line.rindex('"')].strip
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

def download_iplane_data(date, uris)
    tracedir = File.join(IPLANE_DATA_DIR, date)
    Dir.mkdir(tracedir) if not Dir.exist? tracedir

    index_uri = uris['index']
    index_file = File.join(tracedir, index_uri[index_uri.rindex('/')+1..-1])
    if not File.exist? index_file
        puts "Download #{index_file}"
        `curl #{index_uri} -o #{index_file}`
    end

    trace_uri = uris['trace']
    trace_file = File.join(tracedir, trace_uri[trace_uri.rindex('/')+1..-1])
    trace_file_ = trace_file.gsub(".gz", "")
    if not File.exist? trace_file and not File.exist? trace_file_
        puts "Download #{trace_file}"
        `curl #{trace_uri} -o #{trace_file}`
    end

    return [index_file, trace_file]
end

def get_yahoo_astrace_filelist(remote_filelist)
    local_filelist = download_yahoo_data(remote_filelist)
    astrace_filelist = []
    firsthop = nil
    local_filelist.each do |fn|
        reader = AsciiTRFileReader.new(fn)
        output = fn.sub('tracertagent', 'astrace').sub('.gz', '')
        firsthop = convert_to_as_trace(reader, output, firsthop)
        astrace_filelist << output
        puts "[#{Time.now}] Converted #{fn} to AS tracefile #{output}"
    end
    astrace_filelist
end

def get_iplane_astrace_file(date, uris)
    index_file, trace_file = download_iplane_data(date, uris)
    astrace_file = trace_file.sub("trace.out", 'astrace').sub('.gz', '')
    if not File.exist?(astrace_file)
        firsthop = nil
        targetlist = load_target_list
        reader = IPlaneTRFileReader.new(index_file, trace_file)
        conver_to_as_trace(reader, astrace_file, firsthop, targetlist)
    end
    astrace_file
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
