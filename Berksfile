source "https://supermarket.getchef.com"
source 'http://api.berkshelf.com'

cookbooks_path = File.expand_path('../cookbooks', __FILE__)
Dir["#{cookbooks_path}/**"].each do |cookbook_path|
  cookbook File.basename(cookbook_path), path: cookbook_path
end