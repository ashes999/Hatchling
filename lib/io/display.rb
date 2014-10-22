require_relative '../utils/logger'
require 'curses'
include Curses

require_relative('../windows/dos_color_strategy')
require_relative('../linux/rgb_color_strategy')

# Wrapper around the display API (currently Curses).
# width and height are the intended display size, not
# the size of the actual display (eg. the user can resize
# their window to 100x30 even though we just need 80x24).
class Display

	def width
		return 80
	end
	
	def height
		return 24
	end
	
	def initialize
		ENV['TERM'] = 'xterm-256color' # Helps Linux only
		Curses.noecho # do not show typed keys
		Curses.init_screen		
		Curses.start_color
		Curses.stdscr.keypad(true) # Trap arrow keys
		Curses.curs_set(0) # Hide cursor
		
		Logger.info("Running at #{Curses.cols}x#{Curses.lines} with #{Curses.colors} colours")		
		if (Curses.cols < self.width || Curses.lines < self.height) then
			raise "Please resize your terminal to be at least #{self.width}x#{self.height} (currently, it's #{Curses.cols}x#{Curses.lines})"
		end		
		Curses.resizeterm(self.height, self.width)
		
		for n in (0 .. Curses.colors) do
			Curses.init_pair(n, n, 0)
		end
		
		if (Curses.colors > 16)
			@color_strategy = RgbColorStrategy.new(self)
		else
			@color_strategy = DosColorStrategy.new
		end
	end
	
	# Color = { :r => red, :g => green, :b => blue }
	def draw(x, y, text, color)
		return if text.nil? || text.length == 0
		raise "Can't draw #{text} at (#{x}, #{y}); invalid x coordinate" if x < 0 || x >= self.width
		raise "Can't draw #{text} at (#{x}, #{y}); invalid y coordinate" if y < 0 || y >= self.height
		
		color_index = @color_strategy.get_index_for(color)
		Curses.attron(Curses.color_pair(color_index) | A_NORMAL) {
			Curses.setpos(y, x)
			# Seems like a small thing, but using characters is almost twice as fast
			if (text.length <= 1) then
				Curses.addch(text)
			else 
				Curses.addstr(text)
			end
		}		
	end	
	
	def update
		Curses.refresh
	end
	
	##### Higher-level functions #####
	
	def clear
		self.fill_screen(' ', Color.new(0, 0, 0))
	end
	
	def fill_screen(character, color)
		(0 .. self.width - 1).each do |x|
			(0 .. self.height - 1).each do |y|
				self.draw(x, y, character, color)
			end
		end
		
		self.update
	end
	
	##### End higher-level functions #####

	# Used by the Linux strategy to actually set the colour in the window
	# TODO: maybe this can be a callback instead of an explicit method?
	def initialize_color(index, color)
		# Map (0 .. 255) to (0 .. 1000) by multiplying by 4. Max is 1020, so round down.
		Curses.init_color(index, [color.r * 4, 1000].min, [color.g * 4, 1000].min, [color.b * 4, 1000].min)
	end

	
	def destroy
		Logger.info('Terminating display.')
		Curses.close_screen
	end
end
