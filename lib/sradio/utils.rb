require 'erb'
require 'kconv'

class String
  include ERB::Util

  def beautify
    Kconv.toutf8(strip)
  end

  def beautify_as_title
    beautify.downcase.split.collect {|p| p.capitalize}.join("\ ")
  end
end

class Hash
  def subset?(hash)
    self.all? { |k, v| hash[k] && hash[k] == v }
  end
end
