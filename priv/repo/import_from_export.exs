# Import listing data from the little-spider export JSONL file.
#
# Usage:
#   mix run priv/repo/import_from_export.exs [EXPORT_PATH]
#
# Default path: data/paianjen_export.jsonl

defmodule ImportFromExport do
  alias Paianjen.Listings

  def run do
    export_path = System.argv() |> List.first() || default_path()

    IO.puts("Importing from #{export_path}...")

    {meta, groups} = parse_export(export_path)

    IO.puts("Export metadata: #{Jason.encode!(meta)}")
    IO.puts("Found #{length(groups)} groups to import")

    {success, failed} =
      groups
      |> Enum.reduce({0, 0}, fn group, {ok, fail} ->
        entity_id = group["entity_id"]
        listings = group["listings"]

        case Listings.import_group_with_listings(group, listings) do
          {:ok, _group} ->
            IO.puts("  ✓ Imported group #{entity_id} (#{length(listings)} listings)")
            {ok + 1, fail}

          {:error, reason} ->
            IO.puts("  ✗ Failed group #{entity_id}: #{inspect(reason)}")
            {ok, fail + 1}
        end
      end)

    IO.puts("\nImport complete: #{success} succeeded, #{failed} failed")
  end

  defp default_path do
    Path.join([File.cwd!(), "data", "paianjen_export.jsonl"])
  end

  defp parse_export(path) do
    {meta, groups} =
      path
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.reject(&(&1 == ""))
      |> Enum.reduce({nil, []}, fn line, {meta, groups} ->
        case Jason.decode(line) do
          {:ok, %{"exported_at" => _} = m} ->
            {m, groups}

          {:ok, %{"entity_id" => _} = group} ->
            {meta, [group | groups]}

          {:ok, _other} ->
            {meta, groups}

          {:error, reason} ->
            IO.puts("  Warning: failed to parse line: #{inspect(reason)}")
            {meta, groups}
        end
      end)

    {meta, Enum.reverse(groups)}
  end
end

ImportFromExport.run()
