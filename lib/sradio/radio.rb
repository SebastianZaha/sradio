require 'json'
require 'net/http'
require 'time'


class Radio
  attr_reader :stations, :playing

  class << self 
    attr_accessor :icon_registry, :cover_registry
  end

  def initialize
    @stations = []
    Radio.icon_registry, Radio.cover_registry  = SRegistry.new('icons'), SRegistry.new('covers')

    Dir.entries("#{Cfg::DATA}/radios").select {|f| f =~ /.*\.json$/}.each do |file|
      puts "Found config file '#{file}'" if Cfg::DEBUG
      begin
        cfg = JSON.parse(File.read("#{Cfg::DATA}/radios/#{file}"))
        @stations << RadioStation.new(cfg)
      rescue JSON::ParserError
        puts "\tFailed to parse '#{file}'. JSON syntax error."
      end
    end
  end

  def play(station)
    stop if @playing
    @playing = station
    @player = Stream.new
    @player.play(station.stream, station.decoder)
  end

  def stop
    @playing.stop
    @playing = nil
    @player.stop
  end
end




class RadioStation
  attr_reader :name, :decoder, :stream, :icon, :track, :program

  def initialize(cfg)
    @cfg = cfg
    @name, @decoder, @stream = @cfg['name'], @cfg['decoder'], @cfg['stream']
    @icon = Radio.icon_registry.store({'url' => @cfg['icon']}, @cfg['icon'])

    @track = @cfg['track'] ? Track.new(@cfg['track']) : nil
    @program = @cfg['program'] ? Program.new(@cfg['program']) : nil 
  end

  def stop
    @track.stop if @track
    @program.stop if @program
  end
end




class Track
  attr_reader :artist, :title, :album, :album_cover


  def initialize(cfg)
    @cfg = cfg
  end

  def stop
    @artist = @title = @album = @album_cover = nil
  end

  def changed?
    begin
      info = get_current_info
      if info[:artist] == @artist && info[:title] == @title
        puts "\tSame track as before" if Cfg::DEBUG
        return false
      end
      @artist, @title, @album = info[:artist], info[:title], info[:album]
      get_album_and_cover
      return true
    rescue Exception => e
      puts "Error parsing track " +  e.to_s + ":\n" + e.backtrace.join("\n")
    end
  end


  private
  def get_current_info
    uri = URI.parse(@cfg['url'])
    case @cfg['http_method']
    when 'get': str = Net::HTTP.get(uri)
    when 'post': str = Net::HTTP.post_form(uri, {}).body
    end
    str.downcase!

    m = Regexp.new(@cfg['regexp']['artist']).match(str)
    new_artist = m ? m.captures[@cfg['regexp']['artist_match_index']-1].beautify_as_title : nil
    m =  Regexp.new(@cfg['regexp']['title']).match(str)
    new_title = m ? m.captures[@cfg['regexp']['title_match_index']-1].beautify_as_title : nil
    m = @cfg['regexp']['album'] ? Regexp.new(@cfg['regexp']['album']).match(str) : nil
    new_album = m ? m.captures[@cfg['regexp']['album_match_index']-1].beautify_as_title : nil

    puts "\t#{Time.now.strftime("%H:%M:%S")} Parsed artist '#{new_artist}', title '#{new_title}' and album '#{new_album}'" if Cfg::DEBUG
    return {:artist => new_artist, :title => new_title, :album => new_album}
  end


  def get_album_and_cover
    # Do we have a file in the cover_registry? return it. Also if we have an album parsed from musicbrainz, init it.
    key, @album_cover = Radio.cover_registry.get({'artist' => @artist, 'title' => @title})
    if key
      puts "\tFound album cover url in registry: #{@album_cover}"
      @album = key['album'] unless @album
      return
    end

    search = Net::HTTP.post_form(URI.parse('http://musicbrainz.org/taglookup.html'), {:artist => @artist, :track => @title}).body
    m = Regexp.new("<td>(100|9.)</td>([^\"]*\"){8}>.:..</td><td>album</td>([^\"]*\"){3}([^\"]*)\">([^<]*)").match(search) ||     
        Regexp.new("<td>(100|9.)</td>([^\"]*\"){8}>.:..</td><td>single</td>([^\"]*\"){3}([^\"]*)\">([^<]*)").match(search) ||
        Regexp.new("<td>(100|9.)</td>([^\"]*\"){8}>.:..</td><td>compilation</td>([^\"]*\"){3}([^\"]*)\">([^<]*)").match(search)

    puts "\tCan't find album on musicbrainz" if !m && Cfg::DEBUG
    return unless m
    puts "\tFound album on musicbranz: http://musicbrainz.org#{m.captures[3]}" if Cfg::DEBUG

    @album = m.captures[4] unless @album

    search = Net::HTTP.get(URI.parse("http://musicbrainz.org#{m.captures[3]}"))
    m = Regexp.new("asin\"\ src=\"([^\"]*)").match(search)
    
    if m
      album_cover_url = m.captures[0].strip
      return puts("\tCan't find cover on album page") if album_cover_url.empty?
    else
      return puts("\tRegex for cover on album page failed to match")
    end

    puts "\tFound album cover url: '#{album_cover_url}'" if Cfg::DEBUG
    @album_cover = Radio.cover_registry.store({'artist' => @artist, 'title' => @title, 'album' => @album}, album_cover_url)
  end
end




class Program
  attr_reader :current_show, :next_show


  def initialize(cfg)
    @shows = []
    @cfg = cfg
    @gmt_offset = @cfg['utc_offset']
    @day = Time.now.day
  end

  def stop
    @current_show = @next_show = nil
  end


  def changed?
    begin
      if !@shows.empty? && get_next && (Time.now.day == @day)
        return false if @current_show == get_current
      else
        get_current_info
      end
      @current_show, @next_show = get_current, get_next
      return true
    rescue Exception => e
      puts "Error parsing program: " + e.to_s + ":\n" + e.backtrace.join("\n")
    end
  end


  private
  def get_current_info
    puts "\tParsing #{@cfg['url']}" if Cfg::DEBUG
    page = Net::HTTP.get(URI.parse(@cfg['url']))
    rtime = Regexp.new(@cfg['regexp']['time'])
    rtitle = Regexp.new(@cfg['regexp']['title'])
    rdesc = Regexp.new(@cfg['regexp']['description']) if @cfg['regexp']['description']
    @shows = []
    loop do
      break unless m = rtime.match(page)
      t = m.captures[@cfg['regexp']['time_match_index'] - 1].beautify_as_title
      break unless m = rtitle.match(page)
      n = m.captures[@cfg['regexp']['title_match_index'] - 1].beautify_as_title
      
      m = rdesc.match(page) if rdesc
      d = m.captures[@cfg['regexp']['description_match_index'] - 1].beautify if rdesc

      puts "\t\tParsed show: t: '#{t}', n: '#{n}', d: '#{d}'" if Cfg::DEBUG
      add_show(t, n, d)
      page = m.post_match
    end
    raise "Cannot parse schedule" if @shows.length == 0
  end


  def add_show(time, name, description)
    time = Time.parse(time) + Time.now.gmt_offset - @gmt_offset * 3600
    @shows << {:time => time, :name => name, :description => description}
  end


  def get_current
    for i in 0..@shows.length
      return @shows[i] if Time.now > @shows[i][:time] && (@shows[i+1] ? Time.now < @shows[i+1][:time] : true)
    end
  end

  def get_next 
    for i in 0..@shows.length
      return @shows[i+1] if Time.now > @shows[i][:time] && (@shows[i+1] ? Time.now < @shows[i+1][:time] : true)
    end
  end
end
