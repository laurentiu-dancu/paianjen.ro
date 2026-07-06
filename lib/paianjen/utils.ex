defmodule Paianjen.Utils do
  @moduledoc false

  @doc """
  Converts a UTC DateTime or NaiveDateTime to Bucharest local time.
  Returns `{hour, minute}` or `nil` if input is nil.

  Uses manual EU DST calculation — no external dependencies needed.
  Romania (Europe/Bucharest):
    - Winter (EET):  UTC+2
    - Summer (EEST): UTC+3, last Sunday of March 01:00 UTC → last Sunday of October 01:00 UTC
  """
  def to_bucharest_time(%DateTime{} = dt) do
    offset = bucharest_offset(dt.year, dt.month, dt.day, dt.hour)
    total_minutes = dt.hour * 60 + dt.minute + offset * 60
    hour = div(total_minutes, 60) |> rem(24)
    minute = rem(total_minutes, 60)
    {hour, minute}
  end

  def to_bucharest_time(%NaiveDateTime{} = ndt) do
    offset = bucharest_offset(ndt.year, ndt.month, ndt.day, ndt.hour)
    total_minutes = ndt.hour * 60 + ndt.minute + offset * 60
    hour = div(total_minutes, 60) |> rem(24)
    minute = rem(total_minutes, 60)
    {hour, minute}
  end

  def to_bucharest_time(nil), do: nil

  # DST starts last Sunday of March at 01:00 UTC → UTC+3
  # DST ends   last Sunday of October at 01:00 UTC → UTC+2
  defp bucharest_offset(year, month, day, hour) do
    dst_start = last_sunday(year, 3)
    dst_end = last_sunday(year, 10)

    cond do
      month < 3 -> 2
      month == 3 and day < dst_start -> 2
      month == 3 and day == dst_start and hour < 1 -> 2
      month == 3 -> 3
      month > 3 and month < 10 -> 3
      month == 10 and day < dst_end -> 3
      month == 10 and day == dst_end and hour < 1 -> 3
      month == 10 -> 2
      month > 10 -> 2
      true -> 2
    end
  end

  defp last_sunday(year, month) do
    # Last day of the month
    last_day = Date.days_in_month(%Date{year: year, month: month, day: 1})
    # Day of week for last day (1=Mon ... 7=Sun)
    dow = Date.day_of_week(%Date{year: year, month: month, day: last_day})
    # Subtract days to reach Sunday (7)
    last_day - rem(dow, 7)
  end
end
