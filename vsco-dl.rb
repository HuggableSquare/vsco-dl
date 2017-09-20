require 'json'
require 'open-uri'
require 'fileutils'
require 'optparse'

options = {}
parser = OptionParser.new do |opts|
  opts.banner = "Usage: vsco-dl.rb [options] username"

  opts.on "-m", "--[no-]metadata", "Save metadata" do |m|
    options[:metadata] = m
  end

  opts.on "-oOUTPUT", "--output=output", "Where to save the files (default is cwd)" do |o|
    options[:output] = o
  end

  opts.on "-w", "--[no-]overwrite", "Overwrite previously downloaded files" do |w|
    options[:overwrite] = w
  end
end
parser.parse!

user = ARGV[0]
if user.nil?
  $stderr.puts "Error: Username is required."
  $stderr.puts parser
  exit 1
end

# this is v gross, but they probably do it like this on purpose
initial = open "https://vsco.co/#{user}/images/1"
vs = /vs=(\S*);/.match(initial.meta['set-cookie']).captures[0]
siteId = JSON.parse(/window.VSCOVARS.SiteSettings  = ({.*})/.match(initial.read).captures[0])['id']

images = JSON.load(open("https://vsco.co/ajxp/#{vs}/2.0/medias?site_id=#{siteId}&page=0&size=-1", 'Cookie' => "vs=#{vs};"))['media']

path = user
path = File.join options[:output], user unless options[:output].nil?
FileUtils.mkdir_p path unless File.exist? path

images.each_with_index do |r, i|
  print "Image #{i + 1} of #{images.length}\r"
  $stdout.flush

  file_path = File.join path, "#{r['upload_date']}"

  if options[:metadata]
    json_path = "#{file_path}.json"
    if options[:overwrite] or not File.exist? json_path
      File.open json_path, 'w' do |file|
        file.write JSON.pretty_generate r
      end
    end
  end

  jpg_path = "#{file_path}.jpg"
  if options[:overwrite] or not File.exist? jpg_path
    open "https://#{r['responsive_url']}" do |f|
      File.open jpg_path, 'wb' do |file|
        file.write f.read
      end
    end
  end

  if (i + 1) == images.length
    puts "Image #{i + 1} of #{images.length} ...done!"
  end
end
