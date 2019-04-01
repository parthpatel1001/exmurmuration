defmodule Exmurmuration.Scene.Flock do
    use Scenic.Scene
    alias Scenic.Graph
    alias Scenic.ViewPort
    import Scenic.Primitives, only: [text: 3, rrect: 3]

    # Constants
    @graph Graph.build(font: :roboto, font_size: 36)
    
    @tile_radius 12
    @frame_ms 30 # how often to update the frame/tick
    # https://hexdocs.pm/scenic/Scenic.Primitive.Style.Paint.Color.html#content
    @bird_colors [:gold, :dark_orange, :golden_rod, :orange, :orange_red, :yellow, :medium_spring_green]
    
    @num_birds 12 # this number squared will the be the number of birds used
    @z_min 3
    @z_max 5
    @wall_force 50
    @z_scale 4
    @neighbor_distance 2
    @speed_reduce 1 # reduce the direction vector to make animation smoother
    @jitter -6..6
    @wall_buffer 20

    def init(_arg, opts) do
        viewport = opts[:viewport]

        # calculate the transform that centers the flock in the viewport
        {:ok, %ViewPort.Status{size: {vp_width, vp_height}}} = ViewPort.info(viewport)
        IO.inspect(ViewPort.info(viewport))
        # flock initial coordinates
        flock_start_coords = {div(vp_width, 2), div(vp_height, 2)}
        # flock_start_coords = {0, 0}

        # animation timer
        {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

        # hold the state of the flock here
        state = %{
            graph: @graph,
            viewport: viewport,
            boundry: {vp_height-@wall_buffer, vp_width-@wall_buffer, @z_max},
            frame_timer: timer,
            flock: build_flock(flock_start_coords),
        }

        {:ok, state, push: draw_flock(state)}
    end

    # def handle_info(:frame, %{frame_count: frame_count} = state) do
    def handle_info(:frame, state) do
        new_state = state |> move_flock()
        {:noreply, new_state, push: new_state |> draw_flock()}
    end
    
    
    # draw a bird
    defp draw_bird(graph, bird=%{position: {x, y, z}, color: color}) do
        tile_opts = [fill: color, translate: {x, y}]
        size=z #Enum.random(@z_min..z)
        graph |> rrect({
            trunc(size), # width
            trunc(size), # height
            @tile_radius
        }, tile_opts)
    end

    # build an initial flock as a grid
    defp build_bird(x,y,id) do
        %{
            id: id,
            position: {
                Enum.random(50..75), 
                Enum.random(50..60), 
                Enum.random(@z_min..@z_max)
            },
            color: Enum.random(@bird_colors),
            direction: {
                Enum.random(-1..1),
                Enum.random(-1..1),
                0
            }
        } 
    end

    defp build_flock({start_x, start_y}) do
        Enum.reduce(start_x..(start_x + @num_birds), [], fn x, acc ->
            Enum.reduce(start_y..(start_y + @num_birds), acc, fn y, acc ->
                [build_bird(x, y, length(acc)) | acc]
            end)
        end)
    end


    # draw flock
    defp draw_flock(%{graph: graph, flock: flock}) do
        Enum.reduce(flock, graph, fn bird, graph -> 
            draw_bird(graph, bird)
        end)
    end

    defp move_flock(state) do
        %{state | flock: Enum.map(state.flock, &move_bird(state, &1))}
    end


    defp move_bird(state, bird) do
        bird
            |> update_position()
            # |> jitter(state.flock)
            |> cohesion(state.flock)
            |> seperation(state.flock)
            |> alignment(state.flock)
            |> jitter(state.flock)
            |> speed_reduce(state.flock)
            # |> smooth(state.flock)
            # |> update_direction_random(state.flock)
            |> wall_boundry(state.boundry)
            # |> no_z_dir(state.flock)
    end
    defp print_bird(bird) do
        IO.inspect(bird, label: "#{bird.id}")
        bird
    end

    defp update_position(bird) do
        %{bird | position: bird.position |> v_add(bird.direction) }
    end

    defp no_z_dir(bird=%{direction: {x,y,_z}}, flock) do
        %{bird | direction: {x,y,0}}
    end

    defp update_direction_random(bird, flock) do
        %{bird | direction: {Enum.random(-10..10)/10,Enum.random(-10..10)/10,0}}
    end

    defp jitter(bird, flock) do
        %{bird | direction: v_add(bird.direction, {
            Enum.random(@jitter),
            Enum.random(@jitter),
            Enum.random(@jitter)
        })}
    end


    defp cohesion(bird, flock) do
        v = Enum.reduce(Enum.filter(flock, &skip_cur_filter(bird, &1)), {0,0,0}, fn f_bird, vector -> 
            v_add(vector, f_bird.position)
        end)
            |> v_div(length(flock) - 1)
            |> v_sub(bird.position)
            |> v_div(2)
        # v = {Enum.random(-10..10)/10,Enum.random(-10..10)/10,0}
        %{bird | direction: v_add(bird.direction, v)}
    end

    defp seperation(bird, flock) do
        v = Enum.reduce(Enum.filter(flock, &seperation_filter(bird, &1)), {0,0,0}, fn f_bird, vector -> 
            v_sub(vector, v_sub(f_bird.position, bird.position))
        end)
        # v = {Enum.random(-10..10)/10,Enum.random(-10..10)/10,0}
        %{bird | direction: v_add(bird.direction, v)}
    end
    defp alignment(bird, flock) do
        v = Enum.reduce(Enum.filter(flock, &skip_cur_filter(bird, &1)), {0,0,0}, fn f_bird, vector -> 
            vector |> v_add(f_bird.direction)
        end) 
            |> v_div(length(flock) - 1)
            |> v_sub(bird.direction)
        # v = {Enum.random(-10..10)/10,Enum.random(-10..10)/10,0}
        %{bird | direction: v_add(bird.direction, v)}
    end
    defp speed_reduce(bird, _flock), do: %{bird | direction: v_div(bird.direction, @speed_reduce)}


    defp skip_cur_filter(bird, f_bird), do: f_bird.id != bird.id
    defp seperation_filter(bird, f_bird), do: skip_cur_filter(bird, f_bird) and v_mag(v_sub(bird.position, f_bird.position)) < @neighbor_distance

    defp v_mag(v={x,y,z}), do: :math.pow(:math.pow(x, 2) + :math.pow(y, 2), 0.5)
    defp v_sub(v1, v2), do: v_add(v1, v_div(v2, -1))

    defp v_add(v1={x1,y1,z1}, v2={x2,y2,z2}), do: {x1+x2, y1+y2, z1+z2}

    defp v_div(v1={x,y,z}, s) when is_number(s), do: {x/s, y/s, z/s}
    defp v_div(v1={x,y,z}, s={x1,y1,z1}), do: {x/x1, y/y1, z/z1}

    defp wall_boundry(
        bird=%{position: {x,y,z}, direction: {dx,dy,dz}},
        boundry={w,h,d}) do
        %{bird | direction: {
            boundry(x,dx,w, 0, @wall_force),
            boundry(y,dy,h, 0, @wall_force),
            boundry(z,dz,d, @z_min, @z_scale)
        }}
    end
    defp boundry(pos, dir, wall, min, wall_force) when (pos+dir) < min, do: (dir + wall_force)
    defp boundry(pos, dir, wall, min, wall_force) when (pos+dir) <= wall, do: dir
    defp boundry(pos, dir, wall, min, wall_force), do: (dir + wall_force)*-1


end