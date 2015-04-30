require 'digest/sha1'

require_relative 'config.rb'
require_relative 'retrieve_data.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/astrace.rb'
require_relative 'lib/atom.rb'

module BGPAtomAnalysis
def self.analyze(options)
    if options[:duration].nil?
        puts "No duration is given."
        exit
    end

    startdate = options[:start]
    duration = options[:duration]
    selected_as = options[:aslist] # either nil or a list of selected ASNs
    targets = load_target_list
    vp_info = load_iplane_vp_info

    all_tracelist = {}
    puts "Duration: #{duration} days"

    (0...duration).each do |i|
        date = (startdate + i).strftime("%Y%m%d")
        all_tracelist[date] = retrieve_iplane(date)
    end

    startdatestr = startdate.strftime("%Y%m%d")
    selected_vps, selected_as = select_iplane_vps(all_tracelist[startdatestr].keys, selected_as)
    puts "[#{Time.now}] Selected #{selected_as.size} sites"
    output_dir = File.join(IPLANE_OUTPUT_DIR, "atom_#{Digest::SHA1.hexdigest(selected_as.sort.join("-"))}")
    Dir.mkdir(output_dir) if not Dir.exist?(output_dir)
    vplist_fn = File.join(output_dir, "vplist.txt")
    File.delete(vplist_fn) if File.exist?(vplist_fn)

    selected_vps.each do |vp_url|
        vp_url_suffix = vp_url[vp_url.index('.')+1..-1]
        _, vp_asn = vp_info[vp_url]
        File.open(vplist_fn, 'a') { |f| f.puts vp_url_suffix }
        atom_info_map = {}
        available_date = []

        puts "[#{Time.now}] Start for PL site #{vp_url_suffix}"

        (0...duration).each do |i|
            date = (startdate + i).strftime("%Y%m%d")
            tracelist = all_tracelist[date]
            vp = nil
            tracelist.keys.each do |url| 
                if url.end_with?(vp_url_suffix)
                    vp = url
                    break
                end
            end
            next if vp.nil?

            puts "[#{Time.now}] Processing data from #{vp} on #{date}"
            available_date << date
            uris = tracelist[vp]

            index_file, tr_file = download_iplane_data(date, uris)
            reader = IPlaneTRFileReader.new(index_file, tr_file)
            reader.each do |tr|
                next if not targets.include?(tr.dst)
                next if tr.hops.size == 0 or tr.dst != tr.hops[-1][0]
                atom_info_map[tr.dst] = BGPAtom.new(tr.dst) if not atom_info_map.has_key?(tr.dst)
                atom_info_map[tr.dst].add_traceroute(tr)
            end

            astrace_file = get_iplane_astrace_file(date, uris)
            reader = ASTraceReader.new(astrace_file)
            reader.each do |astrace|
                next if not astrace.reached
                astrace.src_asn = vp_asn
                atom_info_map[astrace.dst_ip].add_astrace(astrace)
            end
        end
        
        output_fn = File.join(output_dir, "atom_#{vp_url_suffix}_#{startdatestr}_#{duration}d.txt")
        File.open(output_fn, 'w') do |f|
            f.puts "# dates: #{available_date.join(",")}"
            f.puts
            f.puts "dst_ip,num_of_tr,avg_latency,avg_ashop"
            atom_info_map.each do |ip, atom|
                f.puts "#{ip},#{atom.num_traceroute},#{atom.avg_latency},#{atom.avg_ashop}"
            end
        end
        puts "Output to #{output_fn}"
    end
end
end
