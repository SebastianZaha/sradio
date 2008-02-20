class String
  def beautify_as_title
    h(strip.downcase.split.collect {|p| p.capitalize}.join("\ "))
  end
end

class Hash
  def subset?(hash)
    self.all? { |k, v| hash[k] && hash[k] == v }
  end
end
