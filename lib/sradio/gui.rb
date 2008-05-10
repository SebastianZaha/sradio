require 'gtk2'
require 'libglade2'

class Gui
  def initialize
    @g = GladeXML.new("#{Cfg::DATA}/glade/tooltip.glade", nil, nil)
    @tooltip = Tooltip.new(@g)

    init_status_icon
    init_menu

    Gtk.main
  end

  def init_status_icon
    @status_icon = Gtk::StatusIcon.new
    @status_icon.file = "#{Cfg::DATA}/icons/tray.png"
    @status_icon.signal_connect('popup-menu') { |widget, btn| popup_menu(widget, btn) }
    @status_icon.signal_connect('activate') { @tooltip.toggle }
  end
  
  def init_menu
    @menu = Gtk::Menu.new

    menuItem = Gtk::ImageMenuItem.new('Play')
    menuItem.image = Gtk::Image.new("#{Cfg::DATA}/icons/play.png")
    menuItem.submenu = init_radio_menu
    @menu.append(menuItem)

    menuItem = Gtk::ImageMenuItem.new('Stop')
    menuItem.image = Gtk::Image.new( "#{Cfg::DATA}/icons/stop.png")
    menuItem.signal_connect('activate') { stop }
    @menu.append(menuItem)

    @menu.append(Gtk::SeparatorMenuItem.new)

    menuItem = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
    menuItem.signal_connect('activate') { quit }
    @menu.append(menuItem)
    @menu.show_all
  end

  def init_radio_menu
    menu = Gtk::Menu.new
    Main.radio.stations.each do |s|
      menuItem = Gtk::ImageMenuItem.new(s.name)
      menuItem.image = Gtk::Image.new(Gdk::Pixbuf.new(s.icon).scale(22,22)) if s.icon
      menuItem.signal_connect('activate') { play(s) }
      menu.append(menuItem)
    end
    menu
  end

  def popup_menu(widget, btn)
    @menu.popup(nil, nil, 3, 0) if btn == 3
  end

  def quit
    Gtk.main_quit()
  end

  def error_dialog(type, str)
    dialog = Gtk::MessageDialog.new(@tooltip, Gtk::Dialog::MODAL, Gtk::MessageDialog::ERROR, Gtk::MessageDialog::BUTTONS_OK, type)
    dialog.secondary_text = str
    dialog.run
    dialog.destroy
  end

  def play(station)
    stop if Main.radio.playing
    Main.radio.play(station)

    @tooltip.populate(station)
    if station.track
      @tooltip.refresh_track
      @timeout_track = Gtk.timeout_add(20000) { @tooltip.refresh_track || true } 
    end
    if station.program
      @tooltip.refresh_program
      @timeout_program = Gtk.timeout_add(300000) { @tooltip.refresh_program || true }
    end
  end

  def stop
    Gtk.timeout_remove(@timeout_track) if @timeout_track
    Gtk.timeout_remove(@timeout_program) if @timeout_program
    @tooltip.defaults
    Main.radio.stop
  end
end



class Tooltip
  attr_accessor :g
  
  def initialize(g)
    @g = g
    @g['win_tooltip'].visible = false
    defaults
  end
  
  def toggle
    @g['win_tooltip'].visible = !@g['win_tooltip'].visible?
  end
  
  def show_track; @g['hbox_track'].show; end
  def hide_track; @g['hbox_track'].hide; end
  
  def show_program
    @g['vbox_program'].visible =  @g['hsep_program_song'].visible = true
  end
  
  def hide_program
    @g['vbox_program'].visible = @g['hsep_program_song'].visible = false
  end
  
  def show_album_cover(image)
    @g['img_album_cover'].pixbuf = Gdk::Pixbuf.new(image).scale(120,120)
    @g['img_album_cover'].visible = @g['vsep_cover'].visible = true
  end
  
  def hide_album_cover
    @g['img_album_cover'].visible = @g['vsep_cover'].visible = false
  end
  
  def defaults
    show_track
    @g['lbl_artist'].text = @g['lbl_title'].text = @g['lbl_album'].text = 'Not Available'
    hide_album_cover
    hide_program
  end
  
  def populate(s)
    @station = s
    
    @g['lbl_radio_name'].set_markup("<b>#{@station.name}</b>")
    @g['img_radio_icon'].pixbuf = Gdk::Pixbuf.new(@station.icon).scale(22,22)
    
    if @station.track
      show_track
      @g['lbl_artist'].text = @g['lbl_title'].text = @g['lbl_album'].text = 'Not Available'
      hide_album_cover
    else
      hide_track
    end
    
    if @station.program
      show_program
      ['lbl_program_current', 'lbl_program_current_desc', 'lbl_program_next', 'lbl_program_next_desc'].each { |l| @g[l].text = '' }
    else
      hide_program
    end
  end
  
  def refresh_track
    # changed? will parse data retrieved from the web so we need to break exec from the gui thread to avoid freeze-up
    Thread.new do
      begin
        if @station.track.changed?
          @station.track.artist ? @g['lbl_artist'].set_markup("<b>#{@station.track.artist}</b>") : @g['lbl_artist'].text = 'Not Available'
          @station.track.title ? @g['lbl_title'].set_markup("<b>#{@station.track.title}</b>") : @g['lbl_title'].text = 'Not Available'
          @station.track.album ? @g['lbl_album'].set_markup("<b>#{@station.track.album}</b>") : @g['lbl_album'].text = 'Not Available'
          @station.track.album_cover ? show_album_cover(@station.track.album_cover) : hide_album_cover
        end
      rescue Exception => e
        puts "Exception: " + e.to_s
      end
    end
  end

  def refresh_program
    Thread.new do 
      begin
        if @station.program.changed?
          c = @station.program.current_show
          @g['lbl_program_current'].set_markup("<b>#{c[:time].strftime("%H:%M")}</b>  #{c[:name]}")
          @g['lbl_program_current_desc'].set_markup("  #{c[:description]}")
          if n = @station.program.next_show
            @g['lbl_program_next'].visible = @g['lbl_program_next_desc'].visible = true
            @g['lbl_program_next'].set_markup("<b>#{n[:time].strftime("%H:%M")}</b>  #{n[:name]}")
            @g['lbl_program_next_desc'].text = "  #{n[:description]}"
          else
            @g['lbl_program_next'].visible = @g['lbl_program_next_desc'].visible = false
          end # if n =
        end # if @station
      rescue Exception => e
        puts "Exception: " + e.to_s
      end # begin
    end # thread
  end # def refresh_program
end # class Tooltip
