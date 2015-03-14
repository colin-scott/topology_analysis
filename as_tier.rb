
TIER1 = 800
TIER2 = 50

if $0 == __FILE__
    if ARGV.size < 2
        puts "#{$0} <AS file> <AS link file>"
        exit
    end
    asfile = ARGV[0]
    aslinkfile = ARGV[1]

    aslinks = {}
    File.open(asfile).each_line { |asn| aslinks[asn.chomp] = 0 }
    File.open(aslinkfile).each_line do |line|
        a, b = line.chomp.split
        if a != b
            if not aslinks.include? a
                puts a
            end
            aslinks[a] += 1
            aslinks[b] += 1
        end
    end

    astiers = {}
    tierfile = asfile.sub("AS", "ASTier")
    fout = File.open(tierfile, 'w')
    sorted = aslinks.sort_by { |asn, cnt| cnt }.reverse

    fout.puts "ASN\t#Links\tTier\n"
    sorted.each do |asn, cnt|
        if cnt >= TIER1
            tier = 1
        elsif cnt >= TIER2
            tier = 2
        else
            tier = 3
        end
        astiers[asn] = tier
        fout.puts "#{asn}\t#{cnt}\t#{tier}"
    end
    fout.close
    puts "Output to #{tierfile}"

    tierlinks = {
        [1,1]=> 0, [1,2]=> 0, [1,3]=> 0,
        [2,2]=> 0, [2,3]=> 0, [3,3]=> 0,
        }
    tierlinkfile = asfile.sub("AS", "TierLink")
    File.open(aslinkfile).each_line do |line|
        a, b = line.chomp.split
        if a != b
            min = [astiers[a], astiers[b]].min
            max = [astiers[a], astiers[b]].max
            tierlinks[[min, max]] += 1
        end
    end

    File.open(tierlinkfile, 'w') do |f|
        f.puts "     \tTier1\tTier2\tTier3"
        f.puts "Tier1\t#{tierlinks[[1,1]]}\t#{tierlinks[[1,2]]}\t#{tierlinks[[1,3]]}"
        f.puts "Tier2\t#{tierlinks[[1,2]]}\t#{tierlinks[[2,2]]}\t#{tierlinks[[2,3]]}"
        f.puts "Tier3\t#{tierlinks[[1,3]]}\t#{tierlinks[[2,3]]}\t#{tierlinks[[3,3]]}"
    end
    puts "Output to #{tierlinkfile}"
end
