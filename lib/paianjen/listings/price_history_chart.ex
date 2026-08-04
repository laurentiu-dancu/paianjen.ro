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

  `build/1` (and `build/2` with a `:desktop` / `:mobile` variant) returns a
  plain map of precomputed coordinates, SVG path strings, axis ticks and a
  summary — ready to be consumed by the HEEx template — or `nil` when there is
  nothing worth charting (empty / unparseable history).

  The chart plots the group's minimum price as the main line, shades the
  min–max range band, and highlights price-drop points in green.
  """

  # Chart geometry (SVG viewBox). Two variants: a wide one for desktop and a
  # narrower one for phones. Both are server-rendered and toggled via Tailwind
  # (`hidden lg:block` / `lg:hidden`) so each can be tuned for its own scale.
  @desktop_geometry %{
    width: 800,
    height: 300,
    left: 64,
    right: 16,
    top: 16,
    bottom: 36,
    font_size: 10
  }

  @mobile_geometry %{
    width: 400,
    height: 300,
    left: 48,
    right: 12,
    top: 16,
    bottom: 36,
    font_size: 13
  }

  # Max number of x-axis time labels before they get thinned out.
  @max_time_labels 6

  @doc """
  Build chart data for a group's price_history list. Returns nil if empty.

  `variant` selects the geometry: `:desktop` (wide) or `:mobile` (narrow,
  phone-sized). Defaults to `:desktop`.
  """
  def build(history, variant \\ :desktop)

  def build(history, variant)
      when is_list(history) and variant in [:desktop, :mobile] do
    case parse_points(history) do
      [] -> nil
      points -> build_chart(points, variant)
    end
  end

  def build(_history, _variant), do: nil

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

  defp build_chart(points, variant) do
    %{
      width: width,
      height: height,
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      font_size: font_size
    } = geometry(variant)

    first_date = hd(points).date
    last_date = List.last(points).date

    min_all = points |> Enum.map(& &1.min) |> Enum.min()
    max_all = points |> Enum.map(& &1.max) |> Enum.max()
    {y_lo, y_hi} = y_domain(min_all, max_all)

    plot_w = width - left - right
    plot_h = height - top - bottom
    total_days = max(Date.diff(last_date, first_date), 1)

    %{labels: x_labels, gridlines: gridlines} =
      time_axis(first_date, last_date, total_days, plot_w, left)

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
          x: left + t * plot_w,
          y_min: y_pos(p.min, y_lo, y_hi, plot_h, top),
          y_max: y_pos(p.max, y_lo, y_hi, plot_h, top)
        }
      end)
      |> mark_drops()

    count = length(points)
    has_range = Enum.any?(points, &(&1.max != &1.min))
    # A band / max line is only meaningful when the min and max actually
    # diverge AND there is more than one point to connect. Without this, a
    # single-listing group (min == max everywhere) would draw a dashed max
    # line exactly over the solid min line.
    show_range = has_range and count > 1

    %{
      width: width,
      height: height,
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      font_size: font_size,
      points: points,
      min_line: line_path(points, :y_min),
      max_line: if(show_range, do: line_path(points, :y_max), else: ""),
      band: if(show_range, do: band_path(points), else: ""),
      ticks: y_ticks(y_lo, y_hi, plot_h, top),
      x_labels: x_labels,
      gridlines: gridlines,
      summary: summarize(points),
      has_range: has_range,
      show_range: show_range
    }
  end

  defp geometry(:desktop), do: @desktop_geometry
  defp geometry(:mobile), do: @mobile_geometry

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

  defp y_pos(value, y_lo, y_hi, plot_h, top) do
    top + (1 - (value - y_lo) / (y_hi - y_lo)) * plot_h
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
  defp y_ticks(y_lo, y_hi, plot_h, top) do
    step = nice_step((y_hi - y_lo) / 4)
    start = ceil(y_lo / step) * step

    start
    |> Stream.iterate(&(&1 + step))
    |> Enum.take_while(&(&1 <= y_hi + step / 2))
    |> Enum.map(fn v ->
      %{y: y_pos(v, y_lo, y_hi, plot_h, top), label: tick_label(v)}
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

  # X axis: represents the passage of time at regular intervals. A vertical
  # gridline + label is placed on the 1st of every month inside the range.
  # When the range contains no month boundary (e.g. history shorter than a
  # month), fall back to labelling the first and last dates.
  defp time_axis(first_date, last_date, total_days, plot_w, left) do
    case month_starts_between(first_date, last_date) do
      [] ->
        # No month boundary in range: label first & last dates. Their x
        # positions must be floats — the template runs them through
        # Float.round/2, which rejects integers.
        %{
          labels: [
            %{date: first_date, x: left * 1.0, anchor: "start"},
            %{date: last_date, x: (left + plot_w) * 1.0, anchor: "end"}
          ],
          gridlines: []
        }

      starts ->
        gridlines =
          Enum.map(starts, fn d ->
            %{date: d, x: x_pos(d, first_date, total_days, plot_w, left)}
          end)

        labels = pick_month_labels(starts, first_date, total_days, plot_w, left)
        %{labels: labels, gridlines: gridlines}
    end
  end

  # All 1sts of the month that fall within [first_date, last_date], computed
  # arithmetically (bounded by the real month span, never an unbounded stream).
  # Range checks use Date.compare/2: `%Date{}` structs do NOT order
  # chronologically with `<=` (Erlang term ordering compares the `day` field
  # first), so a Stream.iterate + take_while version of this never terminated
  # and OOM-crashed the VM.
  defp month_starts_between(first_date, last_date) do
    first_month = first_date.year * 12 + (first_date.month - 1)
    last_month = last_date.year * 12 + (last_date.month - 1)

    for month_index <- first_month..last_month do
      %Date{year: div(month_index, 12), month: rem(month_index, 12) + 1, day: 1}
    end
    |> Enum.filter(
      &(Date.compare(&1, first_date) != :lt and Date.compare(&1, last_date) != :gt)
    )
  end

  # Label every month start when there are few, else thin them to ~6 evenly
  # spaced (first and last always included).
  defp pick_month_labels(starts, first_date, total_days, plot_w, left) do
    count = length(starts)

    indices =
      if count <= @max_time_labels do
        Enum.to_list(0..(count - 1))
      else
        step = (count - 1) / (@max_time_labels - 1)
        0..(@max_time_labels - 1) |> Enum.map(&round(&1 * step)) |> Enum.uniq()
      end

    for i <- indices do
      d = Enum.at(starts, i)
      x = x_pos(d, first_date, total_days, plot_w, left)
      %{date: d, x: x, anchor: label_anchor(x, left, plot_w)}
    end
  end

  defp x_pos(date, first_date, total_days, plot_w, left) do
    left + Date.diff(date, first_date) / total_days * plot_w
  end

  # Anchor edge labels so they don't clip outside the viewBox.
  defp label_anchor(x, left, plot_w) do
    cond do
      x - left < 30 -> "start"
      left + plot_w - x < 30 -> "end"
      true -> "middle"
    end
  end

  defp summarize(points) do
    initial = hd(points).min
    current = List.last(points).min
    lowest = points |> Enum.map(& &1.min) |> Enum.min()
    drops = Enum.filter(points, & &1.is_drop)
    last_drop = List.last(drops)

    # All-time max drawdown (initial → lowest). Drives the "has ever dropped"
    # flag and the "last price drop" indicator on the listings cards.
    drop_abs = max(initial - lowest, 0)
    drop_pct = if initial > 0, do: drop_abs / initial * 100, else: 0

    # Current reduction (initial → current). This is what the "Reducere" badge
    # on the show page should display, so a price that dropped then recovered
    # stops being labelled as reduced.
    current_drop_abs = max(initial - current, 0)
    current_drop_pct = if initial > 0, do: current_drop_abs / initial * 100, else: 0

    %{
      initial: initial,
      current: current,
      lowest: lowest,
      drop_abs: drop_abs,
      drop_pct: drop_pct,
      has_drop: drop_abs > 0,
      current_drop_abs: current_drop_abs,
      current_drop_pct: current_drop_pct,
      has_current_drop: current_drop_abs > 0,
      drop_count: length(drops),
      last_drop_date: last_drop && last_drop.date
    }
  end
end
