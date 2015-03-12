require 'date'

require_relative '../config.rb'
require_relative 'traceroute.rb'

def parse_filename fn
    # first remove all the directory
    fn = File.basename(fn)
    # remove extension .gz .log
    fn = File.basename(fn, File.extname(fn)) if fn.end_with? 'gz'
    fn = File.basename(fn, File.extname(fn)) if fn.end_with? 'log'
    # remove prefix
    fn.gsub!("tracertagent-", "")
    vp, timestr = fn.split('-')
    vp.downcase!
    time = DateTime.strptime(timestr, "%Y%m%d.%Hh%Mm%Ss")
    return [vp, time]
end

# Abstract class
class TRFileReader
    attr_reader :filename
    def initialize(filename)
        @filename = unzip(filename)
    end

    def unzip(filename)
        if filename.end_with? '.gz'
            fn_ = filename.gsub('.gz', '')
            if not File.exist? filename
                # check if the file is already decompressed
                raise "File #{filename} doesn't exist" if not File.exist? fn_
                filename = fn_
            else
                `gzip -d #{filename}`
                filename = fn_
            end
        end
        filename
    end
end

class IPlaneTRFileReader < TRFileReader
    include TopoConfig

    def initialize index_file, traceroute_file
        super(traceroute_file)
        @index_file = index_file
        @next_destination = nil

        if not File.exist? READ_OUT or not File.exist? READ_OUT_NO_NTOA
            if not compile_readoutfile
                raise "Could not compile readoutfile. Try manually?"
            end
        end
    end 

    def compile_readoutfile
        ret = nil
        Dir.chdir("readoutfile") do
            ret = system("make")
        end
        ret
    end

    def each &block
        destinations = []
        File.open(@index_file).each_line { |line| destinations << line.split[0] }
        #puts "loaded index file"
        IO.popen("#{READ_OUT} #{@filename}") do |f|
            index = 0
            destinations.each do |destination|
                line = f.gets
                tr = parse_traceroute(line, destination)
                block.call tr
                index += 1
            end
        end
    end

    def parse_traceroute(line, destination)
        hops = line.chomp.split
        dst = hops.shift
        if dst != destination
            puts "Destination mismatch #{dst} <-> #{destination} (#{@filename})"
            return
        end

        # destination = hops.shift
        tr = Traceroute.new(dst)
        ip, lat, ttl = nil, nil, nil
        # TODO(cs): add a link from the VP to the first hop.
        while not hops.empty?
            if hops[0] == "*"
                hops.shift
                tr.append_hop('0.0.0.0', 0.0, 0, 0)
            else
                # TODO(cs): sanity check input.
                ip, lat, ttl = hops.shift, hops.shift.to_f, hops.shift.to_i
                tr.append_hop(ip, lat, ttl, 0)
            end
            # if not ip.nil? and not last_ip.nil?
            #     @database.create_link(last_ip, ip, @vp, destination, ttl, lat)
            # end
        end
        tr
    end
end

class AsciiTRFileReader < TRFileReader
    def initialize filename
        super(filename)
        #@vp, @date = parse_filename @filename
        #@f = File.open(@filename)
    end
        
    # seek to a certain line
    #def seek lno
    #    lno.times { @f.gets }
    #    @lno = lno
    #end

    #def lineno
    #    return nil if @f.nil?
    #    return @f.lineno
    #end

    def each &block
        # Next destination is the first line:
        # D 8.8.8.8 n 14
        # H 0 169.229.49.1 0.302000 255 1415563001
        # H 1 169.229.59.225 0.944000 63 1415563005
        # H 2 128.32.255.57 0.807000 253 1415563009
        # H 3 128.32.0.66 0.297000 252 1415563013
        # H 4 137.164.50.16 0.855000 251 1415563017
        # H 5 137.164.22.27 2.537000 250 1415563021
        # H 6 72.14.205.134 4.219000 249 1415563025
        # H 7 216.239.49.250 3.092000 248 1415563029
        # H 8 209.85.250.60 3.253000 503 1415563033
        # H 9 72.14.232.63 18.594000 500 1415563037
        # H 10 216.239.50.189 21.783001 499 1415563041
        # H 11 64.233.174.131 21.052999 244 1415563045
        # H 12 0.0.0.0 0.000000 0 0
        # H 13 8.8.8.8 21.146999 46 1415563055

        f = File.open(@filename)
        next_dst = f.gets
        _, dstip, _, nhop = next_dst.chomp.split
        tr = Traceroute.new dstip

        # TODO(cs): add a link from the VP to the first hop.
        # TODO(cs): sanity check input.
        while line = f.gets
            line = line.chomp
            if line[0] == 'D'
                block.call tr
                # beginning of new traceroute
                next_dst = line
                _, dstip, _, nhop = next_dst.chomp.split
                tr = Traceroute.new dstip 
            else
                _, _, ip, lat, ttl, timestamp = line.split
                tr.append_hop(ip, lat.to_f, ttl.to_i, timestamp.to_i)
            end
        end
        # last traceroute
        block.call tr
        f.close
    end
end

class YahooTRFileReader
    def initialize filelist
        @filelist = filelist
    end

    def each &block
        while fn = @filelist.shift
            puts "[#{Time.now}] File #{fn}"
            reader = AsciiTRFileReader.new fn
            reader.each &block
        end
    end
end
