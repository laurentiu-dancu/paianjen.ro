defmodule Paianjen.Listings.PriceHistoryChartTest do
  use ExUnit.Case, async: true

  alias Paianjen.Listings.PriceHistoryChart

  # A representative group-level price_history (as stored in the DB jsonb column).
  @history [
    %{
      "date" => "2026-03-19",
      "min_price" => 171_950,
      "max_price" => 171_950,
      "median_price" => 171_950,
      "listing_count" => 1,
      "lowest_price_so_far" => 171_950
    },
    %{
      "date" => "2026-03-25",
      "min_price" => 156_950,
      "max_price" => 156_950,
      "median_price" => 156_950,
      "listing_count" => 1,
      "lowest_price_so_far" => 156_950
    },
    %{
      "date" => "2026-05-14",
      "min_price" => 179_900,
      "max_price" => 179_900,
      "median_price" => 179_900,
      "listing_count" => 1,
      "lowest_price_so_far" => 156_950
    }
  ]

  describe "build/1" do
    test "returns nil for empty or unparseable input" do
      assert PriceHistoryChart.build([]) == nil
      assert PriceHistoryChart.build(nil) == nil
      assert PriceHistoryChart.build(%{}) == nil
      assert PriceHistoryChart.build([%{"foo" => 1}]) == nil
      assert PriceHistoryChart.build([%{"date" => "not-a-date", "min_price" => 100}]) == nil
      assert PriceHistoryChart.build([%{"date" => "2026-03-19"}]) == nil
    end

    test "sorts points chronologically regardless of input order" do
      shuffled = Enum.shuffle(@history)

      chart = PriceHistoryChart.build(shuffled)

      dates = Enum.map(chart.points, & &1.date)
      assert dates == Enum.sort(dates, Date)
    end

    test "maps the date range onto the plot width with x within [left, width - right]" do
      chart = PriceHistoryChart.build(@history)
      assert chart.width == 800

      x_values = Enum.map(chart.points, & &1.x)
      assert Enum.min(x_values) >= 64
      assert Enum.max(x_values) <= 784

      assert hd(chart.points).x == 64.0
      assert List.last(chart.points).x == 784.0
    end

    test "keeps y coordinates inside the plot height" do
      chart = PriceHistoryChart.build(@history)

      y_values = Enum.map(chart.points, & &1.y_min) ++ Enum.map(chart.points, & &1.y_max)
      assert Enum.min(y_values) >= chart.top
      assert Enum.max(y_values) <= chart.top + (chart.height - chart.top - chart.bottom)
    end

    test "marks a point as a drop when the minimum price decreased" do
      chart = PriceHistoryChart.build(@history)

      # 171950 -> 156950 is a drop, 156950 -> 179900 is an increase
      drops = Enum.filter(chart.points, & &1.is_drop)
      assert length(drops) == 1
      assert hd(drops).min == 156_950.0
    end

    test "computes a correct summary" do
      chart = PriceHistoryChart.build(@history)
      summary = chart.summary

      assert summary.initial == 171_950.0
      assert summary.current == 179_900.0
      assert summary.lowest == 156_950.0
      assert summary.has_drop == true
      assert summary.drop_count == 1
      assert summary.drop_abs == 15_000.0
      assert_in_delta summary.drop_pct, 15_000.0 / 171_950.0 * 100, 0.001
      assert summary.last_drop_date == ~D[2026-03-25]
    end

    test "renders a band only when min and max diverge" do
      chart = PriceHistoryChart.build(@history)
      # All points have min == max, so no visible band
      assert chart.band == ""
      assert chart.has_range == false

      ranged = [
        %{"date" => "2026-03-19", "min_price" => 100_000, "max_price" => 110_000},
        %{"date" => "2026-03-25", "min_price" => 95_000, "max_price" => 105_000}
      ]

      ranged_chart = PriceHistoryChart.build(ranged)
      assert ranged_chart.band != ""
      assert ranged_chart.has_range == true
      assert ranged_chart.max_line != ""
    end
  end

  describe "build/1 with a single flat point" do
    test "produces a flat chart with no band or max line" do
      flat = [
        %{
          "date" => "2026-03-17",
          "min_price" => 96_000,
          "max_price" => 96_000,
          "median_price" => 96_000,
          "listing_count" => 1,
          "lowest_price_so_far" => 96_000
        }
      ]

      chart = PriceHistoryChart.build(flat)

      assert length(chart.points) == 1
      assert chart.band == ""
      assert chart.max_line == ""
      assert chart.summary.has_drop == false
      assert chart.summary.initial == 96_000.0
      assert chart.summary.current == 96_000.0
      assert chart.summary.lowest == 96_000.0
    end
  end

  describe "x_labels/ticks" do
    test "labels the x axis at regular month intervals" do
      # @history spans 2026-03-19 → 2026-05-14, so the 1sts of April and May
      # fall inside the range and become the axis labels.
      chart = PriceHistoryChart.build(@history)
      assert Enum.map(chart.x_labels, & &1.date) == [~D[2026-04-01], ~D[2026-05-01]]
    end

    test "adds a vertical gridline on each 1st of the month in range" do
      chart = PriceHistoryChart.build(@history)
      assert Enum.map(chart.gridlines, & &1.date) == [~D[2026-04-01], ~D[2026-05-01]]
    end

    test "falls back to first/last date labels when the range has no month boundary" do
      same_month = [
        %{"date" => "2026-01-02", "min_price" => 100_000, "max_price" => 100_000},
        %{"date" => "2026-01-21", "min_price" => 95_000, "max_price" => 95_000}
      ]

      chart = PriceHistoryChart.build(same_month)
      assert Enum.map(chart.x_labels, & &1.date) == [~D[2026-01-02], ~D[2026-01-21]]
      assert chart.gridlines == []
      # Fallback x positions must be floats — the template calls Float.round/2,
      # which raises on integers (regression for single-month histories).
      assert Enum.all?(chart.x_labels, &is_float(&1.x))
    end

    test "thins month labels when the range spans many months" do
      many =
        for i <- 0..23 do
          d = Date.add(~D[2026-01-01], i * 30)
          %{
            "date" => Date.to_iso8601(d),
            "min_price" => 100_000 + i * 100,
            "max_price" => 100_000 + i * 100
          }
        end

      chart = PriceHistoryChart.build(many)
      assert length(chart.x_labels) <= 6
      assert length(chart.gridlines) > 6
      assert hd(chart.x_labels).date == ~D[2026-01-01]
      assert List.last(chart.x_labels).date == ~D[2027-11-01]
    end

    test "produces at least one y tick with a label" do
      chart = PriceHistoryChart.build(@history)
      assert chart.ticks != []
      assert Enum.all?(chart.ticks, &(is_number(&1.y) and is_binary(&1.label)))
    end
  end
end
