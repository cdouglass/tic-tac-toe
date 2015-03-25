# CLASSES

class Board

  def initialize(x = [[0, 0, 0], [0, 0, 0], [0, 0, 0]])
    @board = x
  end

  def game_won?()
    threes(self).transpose[0].each do |i| # TODO rewrite more cleanly
      x = i[0] * i[1] * i[2]
      if x == 8 || x == 27
        return true
      end
    end
    return false
  end

  def place_piece(play, n)
    i = play[0] # TODO more idiomatic way to unpack?
    j = play[1]
    if ((![0,1,2].include? i) || (![0,1,2].include? j)) # TODO make this nicer
      raise "Coordinates (x=#{i}, y=#{j}) are not acceptable. Please try again."
    end
    if board[j][i] != 0
      raise "Square (#{i}, #{j}) is already occupied by #{board[j][i]}. You cannot play there."
    else
      @board[j][i] = n
    end
  end

  def display()
    @board.each do |i|
      print '|'
      i.each do |j|
        if j == 0
          print ' '
        elsif j == 2
          print 'X'
        else
          print 'O'
        end
      print '|'
      end
      print "\n"
    end
    print "\n"
  end

  def list_available_spaces()
    x = []
    (0..2).to_a.each do |j| # ranges are inclusive in ruby
                            # I suspect this isn't preferred style. What should I do instead?
       (0..2).to_a.each do |i|
        if @board[j][i] == 0
          x << [i, j]
        end
      end
    end
    x
  end

  def self.coordinate_matrix()
    mat = []
    (0..2).to_a.each do |j|
      row = []
      (0..2).to_a.each do |i|
        row << [i, j]
      end
      mat << row
    end
    mat
  end

  def opposite_corner(i,j)
    x = [i,j]
    (0..2).to_a.each do |k|
      if x[k] == 0
        x[k] = 2
      elsif x[k] == 2
        x[k] = 0
      end
    end
    @board[x[1]][x[0]]
  end

  def list_threats(num, mode)
    n = 0
    if mode == :current
      n = 2
    elsif mode == :future
      n = 1
    end
    lst = []
    threes(self).each do |i|
      if i[0][0] + i[0][1] + i[0][2] == n * num && i[0][0] * i[0][1] * i[0][2] == 0
        lst << i[1]
      end
    end
    lst # array of lines - NOT spaces
  end

  def find_forks(threat_list, spaces)
    forks = []
    threat_spaces = my_intersect(threat_list.flatten(1), spaces)
    (0..threat_spaces.length - 1).each do |i|
      x = my_intersect([threat_spaces[i]], threat_spaces[i+1..-1])
      if x.length > 0
        forks << x
      end
    end
    forks = forks.flatten(1)
  end


  def clone()
    Board.new(Marshal.load(Marshal.dump(@board)))
  end
  
  attr_reader :board

end


class Player

  def initialize(n, mode="auto")
    @number = n
    @opp_num = 6 / n # TODO this is a bit magical
    if mode == "auto"
      @mode = :auto
    else
      @mode = :manual
    end
  end

  def play(board)
    if @mode == :auto
      auto_play(board)
    elsif @mode == :manual
      manual_play(board)
    end
    board.display
    if board.game_won?
      puts "Congratulations, player #{number - 1} has won!"
      exit
    elsif board.list_available_spaces.length < 1
      puts "You have tied! Game over."
      exit
    end
  end
  
  def auto_play(board)
    choice = choose_play(board)
    board.place_piece(choice, number) #no error handling
  end

  def choose_play(board)
    spaces = board.list_available_spaces
    if spaces.length < 2
      choice = spaces[0]
      return choice
    end

    my_curr_threats = board.list_threats(number, :current) # array of arrays of 3 positions each
    opp_curr_threats = board.list_threats(opp_num, :current)
    my_fut_threats = board.list_threats(number, :future)
    opp_fut_threats = board.list_threats(opp_num, :future)

    if my_curr_threats.length > 0 # win if possible
      choice = my_intersect(my_curr_threats[0], spaces)[0]
      return choice
    end

    if opp_curr_threats.length > 0 # block opponent win if possible
      choice = my_intersect(opp_curr_threats[0], spaces)[0]
      return choice
    end

    if my_fut_threats.length > 1
      forks = board.find_forks(my_fut_threats, spaces)
      if forks.length > 0 # forks whenever possible
        choice = forks[0]
        return choice
      end
    end

    if opp_fut_threats.length > 1
      forks = board.find_forks(opp_fut_threats, spaces)
      if forks.length > 0 # opponent can fork
        if my_fut_threats.length > 0 # I can make a threat
          my_fut_threats.each do |i|
            overlap = my_intersect(i, forks)
            threat_spaces = my_intersect(i, spaces)
            if overlap.length < 1 # threat line does not intersect forks
               choice = threat_spaces[0]
               return choice
            elsif overlap.length == 1 # threat line does intersect forks but only once
               choice = overlap[0] # play at intersection
               return choice
            end
          end
        end
        choice = forks[0] # play at intersection point of first opponent fork
        return choice
      end
    end    

    if my_fut_threats.length > 0 # make a threat if possible
      threat_spaces = my_intersect(my_fut_threats.flatten(1), spaces)
      choice = threat_spaces[0]
      return choice
    end
    
    if spaces.include? [1,1] # play center
      choice = [1,1]
      return choice

    else
      free_corners = spaces & [[0, 0], [2, 2], [0, 2], [2, 0]]
      opposites = free_corners.map {|a| board.opposite_corner(a[0], a[1])}
      (0..free_corners.length - 1).to_a.each do |i|
        if opp_num == opposites[i]
          choice = free_corners[i]
          return choice
        end
      end
      spaces.each do |j|
        if [[0,0], [2,0], [0,2], [2,2]].include? j
          choice = j
          return choice
        end
      end
    end
   return choice
  end

  def manual_play(board)
     while true
       puts "Player #{number - 1}, please enter x coordinate followed by y coordinate."
       x = gets.chomp.to_i
       y = gets.chomp.to_i
       begin
         board.place_piece([x, y], number)
       rescue RuntimeError => e
         puts e.message
       else break
       end
     end
  end

  attr_reader :number, :opp_num

end

# FUNCTIONS

def diag(x)
  [x[0][0], x[1][1], x[2][2]]
end

def gaid(x)
  [x[2][0], x[1][1], x[0][2]]
end

def threes(y)
  result = []
  [y.board, Board.coordinate_matrix].each do |i|
    x = Marshal.load(Marshal.dump(i))
    x.concat(x.transpose) << diag(x) << gaid(x)
    result << x
  end
  result.transpose # so output groups row (e.g. [0,0,3]) with coordinates (e.g. [[0,0],[0,1],[0,2]])
end

def my_intersect(arr1, arr2) # & seems to be comparing based on object identity, so two arrays containing different [0,0] elements have no intersection. i am sure this is not the best way to get around it.
  result = []
  arr1.each do |i|
    arr2.each do |j|
      if arr_equiv?(i, j)
        result << i
      end
    end
  end
  result
end

def arr_equiv?(arr1, arr2)
  if !arr1.is_a? Array
    return arr1 == arr2
  elsif !arr2.is_a? Array
    return false
  elsif arr1.length != arr2.length
    return false
  else
    return (0..arr1.length - 1).inject(true) { | result, index | result && arr_equiv?(arr1[index], arr2[index]) }
   end
end

def get_modes(numbers)
  modes = []
  numbers.each do |i|
    while true
      puts "Please enter player #{i - 1}'s mode. Press 'a' for auto and 'm' for manual."
      mode = gets.chomp()
      if mode == 'a'
        mode = "auto"
        break
      elsif mode == 'm'
        mode == "manual"
        break
      else
        puts "Not an accepted mode. Try again."
      end
    end
    modes << mode
  end
  modes
end

# GAMEPLAY

numbers = [2,3] # coprime

modes = get_modes(numbers)

players = [Player.new(2, modes[0]), Player.new(3, modes[1])] # TODO this is repetitive

our_board = Board.new()

n = 0
while true
  players.each do |i|
    n = n + 1
    puts "Play #{n}"
    i.play(our_board)
  end
end
