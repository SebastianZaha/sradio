require 'date'
require 'digest/md5'


class SRegistry
  #  The 'data' member of a registry json file is an array of hashes. 
  # If you serialize and md5 a hash, you get the filename it corresponds to.
  attr_reader :data

  def initialize(name)
    @path = Cfg::HOME + "/#{name}"
    Dir.mkdir(@path) unless File.exists?(@path)
    @reg = File.exists?(@path + '.json') ? JSON.parse(File.read(@path + '.json')) : {'version' => '1', 'data' => []}
    # More than 700 items in registry? (10KB per cover)
    purge_old if @reg['data'].length > 700
  end

  def get(hash)
    key = @reg['data'].detect { |h| hash.subset?(h) }
    [key, key ? @path + "/#{filename(key)}" : nil]
  end

  def store(hash, url)
    # Is it already there? No double inserts.
    key, file = get(hash)
    return file if key

    @reg['data'] << hash.merge!({'added_on' => Date.today.to_s})
    store_file(filename(hash), url)
    persist
    
    return "#{@path}/#{filename(hash)}"
  end

  private
  def persist
    File.open(@path + '.json', 'w') do |f|
      f.puts JSON.pretty_unparse(@reg)
    end
  end

  def store_file(fn, url)
    File.open(@path + "/#{fn}", 'w') { |f| f.write(Net::HTTP.get(URI.parse(url))) }
    puts "\tWrote file from '#{url}' in '#{@path}/#{fn}'" if Cfg::DEBUG
  end

  def filename(hash)
    #  As unique as it gets i guess. Serialize the hash and md5 the resulting string.
    #  There's a problem with this though. Hashes have no order for items, by definition. So logically {:a => 1, :b => 2} is 
    # the same as {:b => 2, :a => 1}. But NOT for the fucking serializer it's not. First one is not serialized as the other.
    #  So the stupid hack is to call sort, which gets order into everything...
    Digest::MD5.hexdigest(Marshal.dump(hash.sort))
  end

  def purge_old
    @reg['data'].delete_if do |h|
      # older than one week
      old = (Date.today - Date.parse(h['added_on'])).to_i > 7
      File.delete("#{@path}/#{filename(h)}") if old
      return old
    end
  end
end
