require 'json'
require 'open-uri'

user = ARGV[0]
Dir.mkdir user unless File.exist? user

# this is v gross, but they probably do it like this on purpose
initial = open "https://vsco.co/#{user}/images/1"
vs = /vs=(\S*);/.match(initial.meta['set-cookie']).captures[0]
siteId = JSON.parse(/window.VSCOVARS.SiteSettings  = ({.*})/.match(initial.read).captures[0])['id']

images = JSON.load(open("https://vsco.co/ajxp/#{vs}/2.0/medias?site_id=#{siteId}&page=0&size=-1", 'Cookie' => "vs=#{vs};"))['media']

images.each_with_index do |r, i|
  print "Image #{i + 1} of #{images.length}\r"
  $stdout.flush

  unless File.exist? "#{user}/#{r['upload_date']}.json" and File.exist? "#{user}/#{r['upload_date']}.jpg"
    File.open "#{user}/#{r['upload_date']}.json", 'w' do |file|
      file.write JSON.pretty_generate r
    end
    open "https://#{r['responsive_url']}" do |f|
      File.open "#{user}/#{r['upload_date']}.jpg", 'wb' do |file|
        file.write f.read
      end
    end
  end

  if (i + 1) == images.length
    puts "Image #{i + 1} of #{images.length} ...done!"
  end
end
