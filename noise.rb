module Noise
  class << self
    def white(size)
      Array.new(size) { rand }
    end

    def pink(size)
      pink_noise = []
      b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0

      size.times do
        white = rand - 0.5
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        pink_noise << pink * 0.11
      end

      pink_noise
    end

    def red(size)
      values = white(size)
      values.each_index.map { |i| values[0..i].sum / (i + 1) }
    end

    def brown(size)
      brown = []
      sum = 0
      size.times do
        sum += rand - 0.5
        brown << sum
      end
      brown
    end

    def violet(size)
      white = white(size + 1)
      white.each_cons(2).map { |a, b| b - a }
    end

    def velvet(size, density = 0.1)
      noise = Array.new(size, 0.0)
      (size * density).to_i.times do
        noise[rand(size)] = rand(-1.0..1.0)
      end
      noise
    end

    def gray(size)
      white = white(size)
      pink = pink(size)

      gray_noise = white.each_with_index.map do |white_value, i|
        (white_value + pink[i]) / 2.0
      end

      gray_noise.map! { |v| Math.sin(v * Math::PI) }

      gray_noise
    end

    def fast_poisson_disc_sampling(width:, height:, radius:, k: 30)
      cell_size = radius / Math.sqrt(2)
      grid_width = (width / cell_size).ceil
      grid_height = (height / cell_size).ceil
      grid = Array.new(grid_width) { Array.new(grid_height) }
      queue = []
      points = []

      # Starting point in the center of the canvas
      first_point = [width / 2.0, height / 2.0]
      emit_sample(first_point, queue, grid, grid_width, cell_size, points)

      while queue.any?
        i = rand(queue.size)
        p = queue[i]
        found = false

        k.times do
          q = generate_around(p, radius)
          if within_range(q, width, height) && !near(q, grid, grid_width, grid_height, cell_size, radius)
            emit_sample(q, queue, grid, grid_width, cell_size, points)
            found = true
            break
          end
        end

        queue.delete_at(i) unless found
      end

      points
    end

    def scaled_poisson_disc_sampling(start_x, end_x, range_y, base_radius, k, scaling_table, clumpiness_factor)
      width = end_x - start_x
      height = range_y

      queue = []
      points = []

      cell_size = base_radius / Math.sqrt(2)
      grid_width = (width / cell_size).ceil
      grid_height = (height / cell_size).ceil

      grid = Array.new(grid_width * grid_height)
      initial_point = [start_x + rand * width, rand * height]
      queue << initial_point
      points << initial_point
      insert_point(initial_point, grid, grid_width, grid_height, cell_size)

      until queue.empty?
        current_point = queue.sample
        found = false

        k.times do
          angle = rand * 2 * Math::PI
          radius = base_radius + rand * base_radius
          x = current_point[0] + radius * Math.cos(angle)
          y = current_point[1] + radius * Math.sin(angle)

          next unless within_extent(x, y, start_x, end_x, 0, range_y)

          y_factor = Math.sin((y / range_y) * Math::PI) ** 3
          clumpy_radius = (3 + y_factor) * clumpiness_factor * scaling_table[y.to_i]
          radius_adjusted = clumpy_radius * base_radius

          unless nearby_points(x, y, grid, grid_width, grid_height, cell_size, radius_adjusted)
            new_point = [x, y]
            queue << new_point
            points << new_point
            insert_point(new_point, grid, grid_width, grid_height, cell_size)
            found = true
            break
          end
        end

        queue.delete(current_point) unless found
      end

      points
    end

    private

    def emit_sample(point, queue, grid, grid_width, cell_size, points)
      queue << point
      grid_x = (point[0] / cell_size).to_i
      grid_y = (point[1] / cell_size).to_i
      grid[grid_x][grid_y] = point
      points << point
    end

    def generate_around(point, radius)
      angle = rand * 2 * Math::PI
      distance = Math.sqrt(rand * 3 * radius * radius + radius * radius)
      [point[0] + distance * Math.cos(angle), point[1] + distance * Math.sin(angle)]
    end

    def within_range(point, width, height)
      x, y = point
      x >= 0 && x < width && y >= 0 && y < height
    end

    def near(point, grid, grid_width, grid_height, cell_size, radius)
      x, y = point
      grid_x = (x / cell_size).to_i
      grid_y = (y / cell_size).to_i

      search_radius = 2
      inner_radius_squared = radius * radius

      x0 = [grid_x - search_radius, 0].max
      y0 = [grid_y - search_radius, 0].max
      x1 = [grid_x + search_radius + 1, grid_width].min
      y1 = [grid_y + search_radius + 1, grid_height].min

      (y0...y1).each do |gy|
        (x0...x1).each do |gx|
          neighbor = grid[gx][gy]
          if neighbor && distance_squared(point, neighbor) < inner_radius_squared
            return true
          end
        end
      end
      false
    end

    def distance_squared(a, b)
      dx = b[0] - a[0]
      dy = b[1] - a[1]
      dx * dx + dy * dy
    end

    def insert_point(point, grid, grid_width, grid_height, cell_size)
      x = (point[0] / cell_size).to_i
      y = (point[1] / cell_size).to_i
      grid[y * grid_width + x] = point
    end

    def within_extent(x, y, start_x, end_x, start_y, end_y)
      x >= start_x && x < end_x && y >= start_y && y < end_y
    end

    def nearby_points(x, y, grid, grid_width, grid_height, cell_size, radius)
      grid_x = (x / cell_size).to_i
      grid_y = (y / cell_size).to_i

      radius_squared = radius ** 2
      nearby_cells = (-2..2).flat_map do |dx|
        (-2..2).map do |dy|
          next_x = grid_x + dx
          next_y = grid_y + dy
          next if next_x < 0 || next_y < 0 || next_x >= grid_width || next_y >= grid_height

          grid[next_y * grid_width + next_x]
        end.compact
      end

      nearby_cells.any? do |point|
        distance_squared = (x - point[0])**2 + (y - point[1])**2
        distance_squared < radius_squared
      end
    end

  end
end
