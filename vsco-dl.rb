require 'json'
require 'open-uri'
require 'fileutils'
require 'optparse'
require 'securerandom'

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

  opts.on "-c", "--collection", "Download user's collection if available" do |c|
    options[:collection] = c
  end
end
parser.parse!

user = ARGV[0]
if user.nil?
  $stderr.puts "Error: Username is required."
  $stderr.puts parser
  exit 1
end

print "Loading initial data"

# this endpoint requires the referer for some reason
initial = open "https://vsco.co/content/Static/userinfo",
  'Cookie' => "vs_anonymous_id=#{SecureRandom.uuid}",
  'Referer' => "https://vsco.co/#{user}/images/1"
# the ol' jsonp for same origin requests because why not
vs = JSON.parse(initial.read[/{.+}/])['tkn']

sites = JSON.load open "https://vsco.co/api/2.0/sites?subdomain=#{user}", 'Cookie' => "vs=#{vs}"
# the ol' return an array when you only queried for one thing
site = sites['sites'][0]
site_id = options[:collection] ? site['site_collection_id'] : site['id']

if options[:collection] and not site['has_collection']
  puts
  $stderr.puts "Error: User does not have a collection."
  exit 1
end

# vsco seems to timeout on requests for very large amounts of images
# it also doesn't send the actual total amount of images in requests
# total will either be the real total or page * size + 1, which means
# there's at least one more page of images to be requested (or more)
page = 1
size = 1000
images = []
loop do
  url = options[:collection] ? "https://vsco.co/api/2.0/collections/#{site_id}/medias?page=#{page}&size=#{size}" : "https://vsco.co/api/2.0/medias?site_id=#{site_id}&page=#{page}&size=#{size}"
  response = JSON.load open url, 'Cookie' => "vs=#{vs}"
  key = options[:collection] ? 'medias' : 'media'
  images.concat response[key]
  break if response['total'] <= page * size
  page += 1
end

puts " ...done!"

path = user
path = File.join user, 'collection' if options[:collection]
path = File.join options[:output], user unless options[:output].nil?
FileUtils.mkdir_p path unless File.exist? path

images.each_with_index do |r, i|
  print "Image #{i + 1} of #{images.length}\r"

  file_path = File.join path, "#{r['upload_date']}"

  if options[:metadata]
    json_path = "#{file_path}.json"
    if options[:overwrite] or not File.exist? json_path
      File.open json_path, 'w' do |file|
        file.write JSON.pretty_generate r
      end
    end
  end

  image_url = r['is_video'] ? r['video_url'] : r['responsive_url']
  image_path = "#{file_path}#{File.extname image_url}"
  if options[:overwrite] or not File.exist? image_path
    # opening these with https was oddly buggy and would constantly
    # try to redirect downgrade to http no matter what I did
    open "http://#{image_url}" do |f|
      File.open image_path, 'wb' do |file|
        file.write f.read
      end
    end
  end

  if (i + 1) == images.length
    puts "Image #{i + 1} of #{images.length} ...done!"
  end
end
