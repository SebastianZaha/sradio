require 'gst0.10'

class Stream
  def initialize
    Gst.init
  end

  def play(url, decoder)
    @pipeline = Gst::Pipeline.new
    filesrc = Gst::ElementFactory.make("gnomevfssrc")
    filesrc.location = url
    decoder = Gst::ElementFactory.make(decoder)
    audiosink = Gst::ElementFactory.make("alsasink")
    @pipeline.add(filesrc, decoder, audiosink)
    filesrc >> decoder >> audiosink
    @pipeline.play
  end

  def stop
    @pipeline.stop
  end
end
