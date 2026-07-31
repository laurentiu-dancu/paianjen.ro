defmodule Paianjen.Listings.PriceHistoryChart do
  @moduledoc """
  Turns a listing group's `price_history` column into everything needed to
  render a server-side SVG line chart of price changes over time.

  Input shape (from little-spider's group aggregation, stored as jsonb):

      [
        %{"date" => "2026-03-17", "min_price" => 96000, "max_price" => 96000,
          "median_price" => 96000, "listing_count" => 1,
          "lowest_price_so_far" => 96000},
        ...
      ]

  `build/1` returns a plain map of precomputed coordinates, SVG path strings,
  axis ticks and a summary — ready to be consumed by the HEEx template — or
  `nil` when there is nothing worth charting (empty / unparseable history).

  The chart plots the group's minimum price as the main line, shades the
  min–max range band, and highlights price-drop points in green.
  """

  # Chart geometry (SVG viewBox)
  @width 800
  @height 280
  @left 64
  @right 16
  @top 16
  @bottom 36

  @doc "Build chart data from a group's price_history list. Returns nil if empty."
  def build(history) when is_list(history) do
    case parse_points(history) do
      [] -> nil
      points -> build_chart(points)
    end
  end

  def build(_), do: nil

  # Normalizes the raw list of maps into sorted points with float prices,
  # deduping by date (last occurrence wins, matching the export's collapse).
  defp parse_points(history) do
    history
    |> Enum.reduce(%{}, fn entry, acc ->
      with %{"date" => date_str} when is_binary(date_str) <- entry,
           {:ok, date} <- Date.from_iso8601(date_str),
           min_v when is_number(min_v) <- entry["min_price"],
           max_v when is_number(max_v) <- entry["max_price"] do
        lo = min(min_v, max_v) * 1.0
        hi = max(min_v, max_v) * 1.0

        Map.put(acc, date, %{
          date: date,
          min: lo,
          max: hi,
          median: number_or(entry["median_price"], (lo + hi) / 2),
          count: entry["listing_count"]
        })
      else
        _ -> acc
      end
    end)
    |> Map.values()
    # Date structs are maps, so default term ordering compares `day` before
    # `month`/`year`. Sort explicitly by a {year, month, day} tuple.
    |> Enum.sort_by(fn p -> {p.date.year, p.date.month, p.date.day} end)
  end

  defp number_or(n, _default) when is_number(n), do: n * 1.0
  defp number_or(_, default), do: default

  defp build_chart(points) do
    first_date = hd(points).date
    last_date = List.last(points).date

    min_all = points |> Enum.map(& &1.min) |> Enum.min()
    max_all = points |> Enum.map(& &1.max) |> Enum.max()
    {y_lo, y_hi} = y_domain(min_all, max_all)

    plot_w = @width - @left - @right
    plot_h = @height - @top - @bottom
    total_days = max(Date.diff(last_date, first_date), 1)

    points =
      points
      |> Enum.map(fn p ->
        t = Date.diff(p.date, first_date) / total_days

        %{
          date: p.date,
          min: p.min,
          max: p.max,
          median: p.median,
          count: p.count,
          x: @left + t * plot_w,
          y_min: y_pos(p.min, y_lo, y_hi, plot_h),
          y_max: y_pos(p.max, y_lo, y_hi, plot_h)
        }
      end)
      |> mark_drops()

    count = length(points)

    %{
      width: @width,
      height: @height,
      left: @left,
      right: @right,
      top: @top,
      bottom: @bottom,
      points: points,
      min_line: line_path(points, :y_min),
      max_line: if(count > 1, do: line_path(points, :y_max), else: ""),
      band: if(count > 1, do: band_path(points), else: ""),
      ticks: y_ticks(y_lo, y_hi, plot_h),
      x_labels: x_labels(points),
      summary: summarize(points),
      has_range: Enum.any?(points, &(&1.max != &1.min))
    }
  end

  # A point is a "drop" when the group's minimum price decreased vs the previous
  # change point.
  defp mark_drops(points) do
    count = length(points)

    points
    |> Enum.with_index()
    |> Enum.map(fn {p, i} ->
      prev_min = if i > 0, do: Enum.at(points, i - 1).min, else: p.min

      p
      |> Map.put(:is_drop, p.min < prev_min)
      |> Map.put(:is_first, i == 0)
      |> Map.put(:is_last, i == count - 1)
    end)
  end

  defp y_domain(min_all, max_all) do
    range = max_all - min_all

    if range <= 0 do
      pad = max(min_all * 0.05, 1.0)
      {min_all - pad, min_all + pad}
    else
      pad = range * 0.1
      {min_all - pad, max_all + pad}
    end
  end

  defp y_pos(value, y_lo, y_hi, plot_h) do
    @top + (1 - (value - y_lo) / (y_hi - y_lo)) * plot_h
  end

  defp line_path(points, key) do
    case points do
      [] ->
        ""

      [first | rest] ->
        start = "M #{Float.round(first.x, 1)} #{Float.round(Map.fetch!(first, key), 1)}"
        segs = Enum.map_join(rest, " ", fn p -> "L #{Float.round(p.x, 1)} #{Float.round(Map.fetch!(p, key), 1)}" end)
        start <> " " <> segs
    end
  end

  defp band_path([first | _] = points) do
    top =
      points
      |> Enum.drop(1)
      |> Enum.map_join(" ", fn p -> "L #{Float.round(p.x, 1)} #{Float.round(p.y_min, 1)}" end)

    bottom =
      points
      |> Enum.reverse()
      |> Enum.map_join(" ", fn p -> "L #{Float.round(p.x, 1)} #{Float.round(p.y_max, 1)}" end)

    "M #{Float.round(first.x, 1)} #{Float.round(first.y_min, 1)} #{top} #{bottom} Z"
  end

  # Horizontal gridlines + y labels, using "nice" round steps.
  defp y_ticks(y_lo, y_hi, plot_h) do
    step = nice_step((y_hi - y_lo) / 4)
    start = ceil(y_lo / step) * step

    start
    |> Stream.iterate(&(&1 + step))
    |> Enum.take_while(&(&1 <= y_hi + step / 2))
    |> Enum.map(fn v ->
      %{y: y_pos(v, y_lo, y_hi, plot_h), label: tick_label(v)}
    end)
  end

  defp nice_step(raw) when raw <= 0, do: 1.0

  defp nice_step(raw) do
    exp = :math.log10(raw) |> floor()
    base = :math.pow(10, exp)
    frac = raw / base

    nice_frac =
      cond do
        frac <= 1 -> 1
        frac <= 2 -> 2
        frac <= 5 -> 5
        true -> 10
      end

    nice_frac * base
  end

  defp tick_label(v) do
    v = round(v)

    cond do
      v >= 1_000_000 -> "#{round(v / 1_000_000)}M"
      v >= 10_000 -> "#{round(v / 1_000)}k"
      v >= 1_000 -> format_thousands(v)
      true -> to_string(v)
    end
  end

  defp format_thousands(v) do
    v
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(".")
    |> String.reverse()
  end

  # X-axis date labels: every date when few points, else ~5 evenly spaced.
  defp x_labels(points) do
    count = length(points)

    indices =
      if count <= 6 do
        Enum.to_list(0..(count - 1))
      else
        step = (count - 1) / 4.0
        0..4 |> Enum.map(&round(&1 * step)) |> Enum.uniq()
      end

    for i <- indices do
      p = Enum.at(points, i)
      %{x: p.x, date: p.date}
    end
  end

  defp summarize(points) do
    initial = hd(points).min
    current = List.last(points).min
    lowest = points |> Enum.map(& &1.min) |> Enum.min()
    drops = Enum.filter(points, & &1.is_drop)
    last_drop = List.last(drops)

    drop_abs = max(initial - lowest, 0)
    drop_pct = if initial > 0, do: drop_abs / initial * 100, else: 0

    %{
      initial: initial,
      current: current,
      lowest: lowest,
      drop_abs: drop_abs,
      drop_pct: drop_pct,
      has_drop: drop_abs > 0,
      drop_count: length(drops),
      last_drop_date: last_drop && last_drop.date
    }
  end
end
