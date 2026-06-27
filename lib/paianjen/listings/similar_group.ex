defmodule Paianjen.Listings.SimilarGroup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "similar_groups" do
    field :source_group_id, Ecto.UUID, primary_key: true
    field :similar_group_id, Ecto.UUID, primary_key: true
    field :similarity_score, :float
    field :match_count, :integer, default: 0
    field :algorithm_version, :string
    field :upserted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(sg, attrs) do
    sg
    |> cast(attrs, [:source_group_id, :similar_group_id, :similarity_score, :match_count, :algorithm_version, :upserted_at])
    |> validate_required([:source_group_id, :similar_group_id])
  end
end
