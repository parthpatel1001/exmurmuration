defmodule Exmurmuration.Scene.Flock do
    use Scenic.Scene
    alias Scenic.Graph
    alias Scenic.ViewPort
    import Scenic.Primitives, only: [text: 3, rrect: 3]

    # Constants
    @graph Graph.build(font: :roboto, font_size: 36)
    @num_birds 10 # this number squared will the be the number of birds used
    @tile_size 8
    @spacing 25 # space between birds
    @tile_radius 8
    @frame_ms 192 # how often to update the frame/tick
    # https://hexdocs.pm/scenic/Scenic.Primitive.Style.Paint.Color.html#content
    @bird_colors [:dark_orchid, :dodger_blue, :gold, :white]
    def init(_arg, opts) do
        viewport = opts[:viewport]

        # calculate the transform that centers the flock in the viewport
        {:ok, %ViewPort.Status{size: {vp_width, vp_height}}} = ViewPort.info(viewport)

        # how many tiles can the viewport hold in each dimension?
        vp_tile_width = trunc(vp_width / @tile_size)
        vp_tile_height = trunc(vp_height / @tile_size)

        # flock initial coordinates
        flock_start_coords = {0, 0}

        # animation timer
        {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

        # hold the state of the flock here
        state = %{
            graph: @graph,
            viewport: viewport,
            tile_width: vp_tile_width,
            tile_height: vp_tile_height,
            frame_timer: timer,
            flock: build_flock(flock_start_coords),
        }

        # IO.inspect(state.flock, charlists: :as_lists)
        {:ok, state, push: draw_flock(state)}
    end

    # def handle_info(:frame, %{frame_count: frame_count} = state) do
    def handle_info(:frame, state) do
        state = move_flock(state)

        # {:noreply, %{state | frame_count: frame_count + 1}}
        {:noreply, state, push: state |> move_flock() |> draw_flock()}
    end
    
    
    # draw a bird
    defp draw_bird(graph, {x, y, color}) do
        tile_opts = [fill: color, translate: {x * @tile_size, y * @tile_size}]
        graph |> rrect({@tile_size, @tile_size, @tile_radius}, tile_opts) 
    end

    # build an initial flock as a grid
    defp build_bird(x,y) do
        {
            x + @spacing + @tile_size, 
            y + @spacing + @tile_size, 
            Enum.random(@bird_colors)
        } 
    end

    defp build_flock({start_x, start_y}) do
        Enum.reduce(start_x..(start_x + @num_birds), [], fn x, acc ->
            Enum.reduce(start_y..(start_y + @num_birds), acc, fn y, acc ->
                [build_bird(x, y) | acc]
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
        %{state | flock: Enum.map(state.flock, fn bird -> 
            move_bird(
                state, 
                bird, 
                {Enum.random(-1..1), Enum.random(-1..1)}
            )
        end)}
    end

    defp move_bird(%{tile_width: w, tile_height: h}, _bird={pos_x, pos_y, color}, {vec_x, vec_y}) do
        # {rem(pos_x + vec_x + w, w), rem(pos_y + vec_y + h, h), color}
        {
            boundry_push_back(w, pos_x, vec_x), 
            boundry_push_back(h, pos_y, vec_y), 
            color
        }
    end

    @doc """
        `b`: boundry
        `pos`: current position
        `vec`: move amount

        move the intended vector amount, but if that 
        is past the boundry of the window, squash the vector so it fits
    """
    defp boundry_push_back(b, pos, vec) when pos + vec < b, do: pos + vec
    defp boundry_push_back(b, pos, vec), do: boundry_push_back(b, pos, vec - b)
end