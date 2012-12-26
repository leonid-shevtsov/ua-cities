# Go to http://ru.wikipedia.org/wiki/Города Украины, click 'edit', copy&paste the cities section to db/wikipedia_cities.txt
require 'rubygems'
require 'haml'
require 'yaml'
require 'open-uri'

cities = {}

File.open('db/wikipedia_cities.txt').each_line do |line|
  line.strip!
  next unless line =~ /^.+\[\[(.+)\]\].+\[\[(.+)\]\].*$/
  region_name = $2
  city_name = $1.include?('|') ? $1.split('|').last : $1
  
  cities[region_name] ||= []
  cities[region_name] << city_name
end

cities = cities.to_a.sort{|a,b| a[0] <=> b[0]}
cities.each {|c| c[1].sort}

template = <<END
!!!XML
%regions
  -cities.each do |region|
    %region{:name => region[0]}
      -region[1].each do |city|
        %city{:name => city[:name], :lat => city[:lat], :lon => city[:lon]}
END

@geoapi_key = YAML.load_file('config/google_geo_api.yml')['key']

def geocode(query)
  response = open(build_request('http://maps.google.com/maps/geo', {:q => query, :key => @geoapi_key, :output => 'csv'})).read
  response.split("\n").map { |r| r.split(',') }
end

def build_request(endpoint_url, params)
  #TODO hack
  URI.parse(endpoint_url).merge('geo?'+params.map{|a,b| "#{a}=#{URI.escape(b)}"}.join("&")).to_s
end

def get_lat_lon(city, region)
  begin
    response = geocode("#{city}, Украина")
    latitude = nil
    longitude = nil
    max_precision = -1
    response.each do |coordinates|
      next if coordinates[0].to_i != 200
      if coordinates[1].to_i > max_precision
        latitude = coordinates[2].to_f
        longitude = coordinates[3].to_f
        max_precision = coordinates[1].to_i
      end
    end
  end
  puts "#{city} #{region} #{latitude} #{longitude}"
  [latitude, longitude]
end

cities.each do |region|
  region[1].map!{ |city| latlon = get_lat_lon(city, region[0]); {:name => city, :lat => latlon[0], :lon => latlon[1]}}
end

File.open('db/cities.xml','w') {|f| f.write Haml::Engine.new(template).render(Object.new, :cities => cities)}


