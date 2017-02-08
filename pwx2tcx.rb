
#~ gem install timezone

require 'rubygems'
require 'date'
require 'nokogiri'
require 'time' # for xmlschema
require 'timezone'

exit if __FILE__ != $0

Position = Struct.new( :time, :latitude, :longitude, :height )

Timezone::Lookup.config(:geonames) do |c|
  c.username = ''  # Add user name
end

def AddFile( input_path, builder )

  doc = File.open(input_path) do |f|
    Nokogiri::XML(f)
  end

  doc.remove_namespaces!

  # Use the first position to get the time zone
  latitude = doc.at_xpath("//workout/sample/lat").content
  longitude = doc.at_xpath("//workout/sample/lon").content
  
  puts "  Co-ordinate for time zone: #{latitude}, #{longitude}"
  
  timezone = Timezone.lookup(latitude, longitude)
  puts "  Time zone: #{timezone}"

  offset = (Time.now-timezone.time(Time.now))
  puts offset/3600
  
  title = File.basename( input_path, File.extname(input_path) )
  pwx_time = doc.at_xpath("//workout/time").content
  pwx_time << "Z"
  start_time = Time.parse( pwx_time ) + offset
  puts start_time.utc.xmlschema
  
  positions = []

  doc.xpath("//sample").each { |sample|
    begin
      time_offset = sample.at_xpath( "timeoffset" ).content.to_f
      latitude = sample.at_xpath( "lat" ).content
      longitude = sample.at_xpath( "lon" ).content
      height = sample.at_xpath( "alt" ).content           
    rescue
      next
    end
    positions << Position.new( (start_time + time_offset), latitude, longitude, height )
  }

  builder.Activity( "Sport" => "Biking" ) { |builder|
    builder.Id start_time.xmlschema
    builder.Lap( "StartTime" => start_time.xmlschema ) {
      builder.TotalTimeSeconds doc.at_xpath("//workout/summarydata/duration").content
      builder.DistanceMeters doc.at_xpath("//workout/summarydata/dist").content
      builder.Calories 0
      builder.Intensity "Active"
      builder.TriggerMethod "Manual"
      builder.Track {
        positions.each { |position|
          builder.Trackpoint { 
            builder.Time position.time.xmlschema
            builder.Position {
              builder.LatitudeDegrees position.latitude
              builder.LongitudeDegrees position.longitude
            }
            builder.AltitudeMeters position.height           
          }
        }
      }
    }
  }


end


input_path = ARGV[0]


NS = {
  "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
  "xmlns:schemaLocation"  => "http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd",
  "xmlns"     => "http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2",
}


builder = Nokogiri::XML::Builder.new do |xml|
  xml.TrainingCenterDatabase(NS) {
    xml.Activities{
    
      Dir.glob( "*.pwx" ) do |path|
        puts path
        AddFile( path, xml )
      end
    
    }
  }
end

File.open( "export.tcx", "wt") do |f|
  f.write builder.to_xml
end
