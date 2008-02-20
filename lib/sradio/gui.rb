require 'gtk2'
require 'libglade2'

class Gui
  def initialize
    init_status_icon
    init_menu
    init_tooltip
    Gtk.timeout_add(20000) { refresh_track_data || true }
    Gtk.timeout_add(300000) { refresh_program_data || true }
    Gtk.main
  end

  def init_status_icon
    @status_icon = Gtk::StatusIcon.new
    @status_icon.file = "#{Cfg::DATA}/icons/tray.png"
    @status_icon.signal_connect('popup-menu') { |widget, btn| popup_menu_cb(widget, btn) }
    @status_icon.signal_connect('activate') { tooltip_toggle }
  end
  
  def init_menu
    @menu = Gtk::Menu.new

    menuItem = Gtk::ImageMenuItem.new('Play')
    menuItem.image = Gtk::Image.new("#{Cfg::DATA}/icons/play.png")
    menuItem.submenu = init_radio_menu
    @menu.append(menuItem)

    menuItem = Gtk::ImageMenuItem.new('Stop')
    menuItem.image = Gtk::Image.new( "#{Cfg::DATA}/icons/stop.png")
    menuItem.signal_connect('activate') { stop_cb }
    @menu.append(menuItem)

    @menu.append(Gtk::SeparatorMenuItem.new)

    menuItem = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)
    menuItem.signal_connect('activate') { quit_cb }
    @menu.append(menuItem)
    @menu.show_all
  end

  def init_radio_menu
    menu = Gtk::Menu.new
    Main.radio.stations.each do |s|
      menuItem = Gtk::ImageMenuItem.new(s.name)
      menuItem.image = Gtk::Image.new(Gdk::Pixbuf.new(s.icon).scale(22,22)) if s.icon
      menuItem.signal_connect('activate') { play_cb(s) }
      menu.append(menuItem)
    end
    menu
  end

  def init_tooltip
    @g = GladeXML.new("#{Cfg::DATA}/glade/tooltip.glade", nil, nil)
    @tooltip = @g['win_tooltip']
    @tooltip.visible = false
    refresh_tooltip_data
  end


##################################################
##################################################

  def refresh_tooltip_data
    refresh_track_data
    refresh_program_data
    return unless s = Main.radio.playing
    @g['lbl_radio_name'].set_markup("<b>#{s.name}</b>")
    @g['img_radio_icon'].pixbuf = Gdk::Pixbuf.new(s.icon).scale(22,22)
  end

  def refresh_program_data
    return hide_program unless s = Main.radio.playing
    Thread.new do 
      refresh_program_ui(s) if s.refresh_program
    end
  end

  def refresh_program_ui(s)
    program = s.program.get_current_next
    @g['lbl_program_current'].set_markup("<b>#{program[0][:time].strftime("%H:%M")}</b>  #{program[0][:name]}")
    @g['lbl_program_current_desc'].set_markup("  #{program[0][:description]}")
    if program[1]
      @g['lbl_program_next'].set_markup("<b>#{program[1][:time].strftime("%H:%M")}</b>  #{program[1][:name]}")
      @g['lbl_program_next_desc'].set_markup("  #{program[1][:description]}")
    else
      @g['lbl_program_next'].hide
      @g['lbl_program_current_desc'].hide
    end
    show_program unless @g['vbox_program'].visible?
  end

  def refresh_track_data
    unless s = Main.radio.playing
      @g['lbl_artist'].text = @g['lbl_title'].text = @g['lbl_album'].text = 'Not Available'
      return hide_album_cover
    end
    Thread.new do
      refresh_track_ui(s) if s.refresh_track_info
    end
  end

  def refresh_track_ui(s)
    s.artist ? @g['lbl_artist'].set_markup("<b>#{s.artist}</b>") : @g['lbl_artist'].text = 'Not Available'
    s.title ? @g['lbl_title'].set_markup("<b>#{s.title}</b>") : @g['lbl_title'].text = 'Not Available'
    s.album ? @g['lbl_album'].set_markup("<b>#{s.album}</b>") : @g['lbl_album'].text = 'Not Available'
    s.album_cover ? show_album_cover(s.album_cover) : hide_album_cover
  end

  def show_program
    @g['vbox_program'].show
    @g['hsep_program_song'].show
  end

  def hide_program
    @g['vbox_program'].hide
    @g['hsep_program_song'].hide
  end

  def show_album_cover(image)
    @g['img_album_cover'].pixbuf = Gdk::Pixbuf.new(image).scale(120,120)
    @g['img_album_cover'].visible = @g['vsep_cover'].visible = true
  end

  def hide_album_cover
    @g['img_album_cover'].visible = @g['vsep_cover'].visible = false
  end

  def popup_menu_cb(widget, btn)
    @menu.popup(nil, nil, 3, 0) if btn == 3
  end

  def tooltip_toggle
    @tooltip.visible = !@tooltip.visible?
  end

  def play_cb(station)
    Main.radio.play(station)
    refresh_tooltip_data
  end

  def stop_cb
    Main.radio.stop
    refresh_tooltip_data
  end
 
  def quit_cb
    Gtk.main_quit()
  end

  def error_dialog(type, str)
    dialog = Gtk::MessageDialog.new(@tooltip, Gtk::Dialog::MODAL, Gtk::MessageDialog::ERROR, Gtk::MessageDialog::BUTTONS_OK, type)
    dialog.secondary_text = str
    dialog.run
    dialog.destroy
  end
end
