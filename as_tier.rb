require 'set'

TIER1 = 800
TIER2 = 50

if $0 == __FILE__
    if ARGV.size < 2
        puts "#{$0} <AS file> <AS link file>"
        exit
    end
    asfile = ARGV[0]
    aslinkfile = ARGV[1]

    as_peers = {}
    File.open(asfile).each_line do |line| 
        next if line.start_with?('#')
        asn = line.split[0].to_i
        as_peers[asn] = Set.new
    end
    File.open(aslinkfile).each_line do |line|
        a, b = line.chomp.split
        a = a.to_i
        b = b.to_i
        next if a == b
        as_peers[a] << b 
        as_peers[b] << a
    end

    as_degree = {}
    as_tiers = {}
    as_peers.each { |asn, peers| as_degree[asn] = peers.size }
    sorted = as_degree.sort_by { |asn, cnt| cnt }.reverse

    tierfile = asfile.sub("AS", "AS_Tier")
    fout = File.open(tierfile, 'w')
    fout.puts "ASN\t#Links\tTier\n"
    sorted.each do |asn, cnt|
        if cnt >= TIER1
            tier = 1
        elsif cnt >= TIER2
            tier = 2
        else
            tier = 3
        end
        as_tiers[asn] = tier
        fout.puts "#{asn}\t#{cnt}\t#{tier}"
    end
    fout.close
    puts "Output to #{tierfile}"

    tierlinks = {
        [1,1]=> 0, [1,2]=> 0, [1,3]=> 0,
        [2,2]=> 0, [2,3]=> 0, [3,3]=> 0,
        }
    tierlinkfile = asfile.sub("AS", "Tier_Links")
    aslinks = Set.new
    File.open(aslinkfile).each_line do |line|
        a, b = line.chomp.split
        a = a.to_i
        b = b.to_i
        next if a == b
        if not aslinks.include?([a,b])
            aslinks << [a,b]
            aslinks << [b,a]
            min = [as_tiers[a], as_tiers[b]].min
            max = [as_tiers[a], as_tiers[b]].max
            tierlinks[[min, max]] += 1
        end
    end

    File.open(tierlinkfile, 'w') do |f|
        f.puts "     \tTier1\tTier2\tTier3"
        f.puts "Tier1\t#{tierlinks[[1,1]]}\t#{tierlinks[[1,2]]}\t#{tierlinks[[1,3]]}"
        f.puts "Tier2\t\t#{tierlinks[[2,2]]}\t#{tierlinks[[2,3]]}"
        f.puts "Tier3\t\t\t#{tierlinks[[3,3]]}"
    end
    puts "Output to #{tierlinkfile}"

    File.open("AS3356.txt", 'w') do |f|
        as_peers[3356].sort.each { |asn| f.puts(asn) }
    end
end
