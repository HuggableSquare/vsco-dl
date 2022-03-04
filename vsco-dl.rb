require 'json'
require 'open-uri'
require 'fileutils'
require 'optparse'
require 'securerandom'

def parse_options
  options = {}
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: vsco-dl.rb [options] username (or site id)"

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

    opts.on "-s", "--site-id", "Download user via site id instead of username" do |s|
      options[:site_id] = s
    end

    opts.on "-i", "--input=file.txt", "Download all users from an input file" do |i|
      options[:input] = i
    end
  end
  parser.parse!
  options
end


def download(user, options)
  # bearer token seems to be hardcoded for logged out users
  authorization = "Bearer 7356455548d0a1d886db010883388d08be84d0c9"
  # api seems to 403 on requests with no user-agent
  user_agent = "vsco-dl"

  headers = { 'Authorization' => authorization, 'User-Agent' => user_agent }

  if user.nil?
    type = options[:site_id] ? "Site id" : "Username"
    $stderr.puts "Error: #{type} is required."
    $stderr.puts parser
    exit 1
  end

  print "Loading initial data"

  site = nil
  if options[:site_id]
    sites = JSON.load open "https://vsco.co/api/2.0/sites/#{user}", headers
    site = sites['site']
    # set user back to a username
    user = site['subdomain']
  else
    sites = JSON.load open "https://vsco.co/api/2.0/sites?subdomain=#{user}", headers
    # the ol' return an array when you only queried for one thing
    site = sites['sites'][0]
  end

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
  # seems like collection requests have a hard cap at 60 no matter what
  size = options[:collection] ? 60 : 1000
  images = []
  loop do
    url = options[:collection] ?
      "https://vsco.co/api/2.0/collections/#{site['site_collection_id']}/medias?page=#{page}&size=#{size}" :
      "https://vsco.co/api/2.0/medias?site_id=#{site['id']}&page=#{page}&size=#{size}"
    response = JSON.load open url, headers
    key = options[:collection] ? 'medias' : 'media'
    images.concat response[key]
    break if response['total'] <= page * size
    page += 1
  end

  puts " ...done!"

  path = user
  path = File.join options[:output], user unless options[:output].nil?
  path = File.join path, 'collection' if options[:collection]
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
end

options = parse_options

if options[:input].nil?
  download ARGV[0], options
else
  File.foreach options[:input] do |user|
    download user.strip, options
  end
end
