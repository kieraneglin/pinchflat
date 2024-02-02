defmodule Pinchflat.Tasks.Task do
  @moduledoc """
  The Task schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.Media.MediaItem
  alias Pinchflat.MediaSource.Source

  schema "tasks" do
    belongs_to :job, Oban.Job
    belongs_to :source, Source
    belongs_to :media_item, MediaItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:job_id, :source_id, :media_item_id])
    |> validate_required([:job_id])
  end
end
