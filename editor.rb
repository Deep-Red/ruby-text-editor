# io/console needed to allow raw editing mode
require "io/console"

class Editor
  def initialize
    if ARGV.size == 1
		@current_file = ARGV[0]
		lines = openfile(@current_file) 
	elsif ARGV.size == 0
		puts "What would you like to name your new file?"
		@current_file = gets.chomp
		lines = File.new(@current_file, "w+")
	end
	@file = lines
    @buffer = Buffer.new(lines)
    @cursor = Cursor.new
    @history = []
  end

  def run
    # puts console into raw mode
    IO.console.raw do
      # renders the current buffer and handles user input
      loop do
        render
        handle_input
      end
    end
  rescue
    50.times { puts }
    raise
  end

  def render
    ANSI.clear_screen
    ANSI.move_cursor(0, 0)
    @buffer.render
    # move the cursor to proper position
    ANSI.move_cursor(@cursor.row, @cursor.col)
  end

  def handle_input
    #get a single character of input
    char = $stdin.getc
    case char
    # handle escape sequences
    when "\e" then handle_escape
    # ctrl-q causes the editor to exit
    when "\C-q" then quit
    when "\C-s" then save_file(@current_file)
    # emacs style commands to move cursor
    when "\C-p" then @cursor = @cursor.up(@buffer)
    when "\C-n" then @cursor = @cursor.down(@buffer)
    when "\C-b" then @cursor = @cursor.left(@buffer)
    when "\C-f" then @cursor = @cursor.right(@buffer)
    # handle tab
    when "\C-I"
      # would like to eventually implement true tabs, need to figure out how to
      # tell how many columns a single character tab takes up in order to move
      # the cursor to the next tab stop
      # oldlen = @buffer.line_length(@cursor.row)
      # newlen = @buffer.line_length(@cursor.row)
      # tabdist = newlen - oldlen
      # @buffer = @buffer.insert( 9.chr, @cursor.row, @cursor.col)
      4.times do
        @buffer = @buffer.insert( 32.chr, @cursor.row, @cursor.col)
        @cursor = @cursor.right(@buffer)
      end
    # handle undo
    when "\C-u" then restore_snapshot
    # handle midline break
    when "\r"
      save_snapshot
      @buffer = @buffer.split_line(@cursor.row, @cursor.col)
      @cursor = @cursor.down(@buffer).move_to_col(0)
    # handle backspace (could change format later for consistency)
    when 127.chr
      save_snapshot
      # backspace does not work if cursor is on column zero (will need to be changed if linewrap is implemented)
      if @cursor.col > 0
        # remove preceding character
        @buffer = @buffer.delete(@cursor.row, @cursor.col - 1)
        # move cursor to the left
        @cursor = @cursor.left(@buffer)
      end
    # insert any other character literally into the buffer
    else
      save_snapshot
      @buffer = @buffer.insert(char, @cursor.row, @cursor.col)
      # move cursor to right after inserting character
      @cursor = @cursor.right(@buffer)
    end
  end

  # Handle escape
  def handle_escape
    seq = []
    2.times do
      seq << $stdin.getc
    end

    case seq[1]
    when "A" then @cursor = @cursor.up(@buffer)
    when "B" then @cursor = @cursor.down(@buffer)
    when "C" then @cursor = @cursor.right(@buffer)
    when "D" then @cursor = @cursor.left(@buffer)
    end
  end

  def save_snapshot
    @history << [@buffer, @cursor]
  end

  def restore_snapshot
    if @history.length > 0
      @buffer, @cursor = @history.pop
    end
  end

  # Loads lines from file.
  def openfile(file)
    lines = File.readlines(file).map do |line|
      line.sub(/\n$/, "")
    end
    return lines
  end

  # Saves current buffer to file with specified name
  def save_file(filename)
    puts "Saving..."
    File.open(filename, 'w') do |f|
      f.puts @buffer.lines
    end
  end

  def quit
    ANSI.clear_screen
    ANSI.move_cursor(0, 0)
    exit(0)
  end

end

# class to represent contents of file
class Buffer
  attr_reader :lines
  # assigns lines to an instance variable
  def initialize(lines)
    @lines = lines
    lines = lines
  end

  def insert(char, row, col)
    # deep copy lines
    lines = @lines.map(&:dup)
    # inserts typed character
    lines.fetch(row).insert(col, char)
    Buffer.new(lines)
  end

  def delete(row, col)
    lines = @lines.map(&:dup)
    # deletes character at specified row and column
    lines.fetch(row).slice!(col)
    Buffer.new(lines)
  end

  def split_line(row, col)
    lines = @lines.map(&:dup)
    line = lines.fetch(row)
    lines[row..row] = [line[0...col], line[col..-1]]
    Buffer.new(lines)
  end

  def render
    # writes @lines to the screen
    @lines.each do |line|
      $stdout.write(line + "\r\n")
    end
  end

  def line_count
    @lines.count
  end

  def line_length(row)
    @lines.fetch(row).length
  end
end

# represents the position of the cursor on the screen
class Cursor
  attr_reader :row, :col

  def initialize(row=0, col=0)
    @row = row
    @col = col
  end

  # methods to move cursor
  def up(buffer)
    Cursor.new(@row - 1, @col).clamp(buffer)
  end

  def down(buffer)
    Cursor.new(@row + 1, @col).clamp(buffer)
  end

  def left(buffer)
    Cursor.new(@row, @col - 1).clamp(buffer)
  end

  def right(buffer)
    Cursor.new(@row, @col + 1).clamp(buffer)
  end

  # restricts values to a reasonable range
  def clamp(buffer)
    # between 0 and the row count
    row = @row.clamp(0, buffer.line_count - 1)
    # greater than 0, but can go one past the column count
    col = @col.clamp(0, buffer.line_length(row))
    Cursor.new(row, col)
  end

  def move_to_col(col)
    # probably worth changing this hard coded 0 to a variable
    Cursor.new(row, 0)
  end

end

class ANSI
  def self.clear_screen
    # uses clear screen control key
    $stdout.write("\e[2J")
  end

  def self.move_cursor(row, col)
    # uses move_cursor control key
    # Adding 1 because editor is 0 indexed
    $stdout.write("\e[#{row + 1};#{col + 1}H")
  end
end

Editor.new.run
