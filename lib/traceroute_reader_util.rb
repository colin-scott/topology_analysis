require 'date'

# Abstract class
class TracerouteFileReader
  ReadOutFile = "./readoutfile/readoutfile_no_ntoa"

  def initialize(filename, database)
    @filename = unzip(filename)
    @vp, @date = get_vp_date_from_filename(@filename)
    @database = database
  end

  def unzip(filename)
    if filename.end_with? '.gz'
       `gzip -d #{filename}`
       filename = filename[0...-3]
    end
    filename
  end

  def get_vp_date_from_filename(filename)
    sub = File.basename(filename)
    sub = File.basename(sub, File.extname(sub))
    sub.gsub!("tracertagent-", "")
    vp, datestr = sub.split('-')
    vp.downcase!
    date = DateTime.strptime(datestr, "%Y%m%d.%Hh%Mm%Ss")
    return [vp, date]
  end
end

