require_relative 'utilities.rb'
require_relative 'asmapper.rb'

# -2: unresponsive hop
# -1: private IP
#  0: no ASN found
def generate_as_trace(tr)
    astrace = []
    # generate as list
    tr.hops.each do |ip,_,ttl,_|
        if ttl == 0
            # missing hop
            astrace << -2
        elsif Inet::in_private_prefix_q? ip
            # use -1 to indicate private IP addr
            astrace << -1
        else
            asn = ASMapper.query_asn ip
            if asn.nil?
                astrace << 0
            else
                astrace << asn
            end
        end
    end
    astrace
end

# args:
#   reader: traceroute rader
#   output: output file name
#   firsthop: the missing firsthop. if don't know, just use nil
#   targetlist: target dst ip list used to filter out irrelevant trs
# return: firsthop
def convert_to_as_trace(reader, output, firsthop, targetlist=nil)
    fout = File.open(output, 'w')

    reader.each do |tr|
        next if not targetlist.nil? and not targetlist.include?(tr.dst)
        next if tr.hops.size == 0

        # fill in the missing first hop skipped by traceroute
        firsthop = tr.hops[0] if firsthop.nil? and tr.hops[0][2] != 0
        tr.hops[0] = firsthop if not firsthop.nil? and tr.hops[0][2] == 0

        astrace = generate_as_trace(tr)
        reached = (tr.dst == tr.hops[-1][0])

        fout.print "#{tr.dst} #{reached}"
        astrace.each { |asn| fout.print(" #{asn}") }
        fout.puts
    end

    fout.close()
    return firsthop
end

class ASTrace
    attr_accessor :src_asn
    attr_reader :dst, :reached, :hops
    def initialize(dst, reached)
        @src_asn = nil
        @dst = dst
        @reached = reached
        @hops = []
    end

    def to_s
        str = "#{@dst} #{@reached}"
        @hops.each { |asn| str += " #{asn}" }
        str
    end
end

class ASTraceReader
    def initialize(file)
        if file.kind_of?(Array)
            @filelist = file
        else
            @filelist = [file]
        end
    end

    def each &block
        @filelist.each do |fn|
            File.open(fn).each do |line|
                hops = line.chomp.split
                dst = hops.shift
                reached = (hops.shift == 'true')
                astrace = ASTrace.new(dst, reached)
                hops.each { |asn| astrace.hops << asn.to_i }
                block.call(astrace)
            end
        end
    end
end
