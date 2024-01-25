defmodule Pinchflat.Tasks.Task do
  @moduledoc """
  The Task schema.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pinchflat.MediaSource.Channel

  schema "tasks" do
    belongs_to :job, Oban.Job
    belongs_to :channel, Channel

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:job_id, :channel_id])
    |> validate_required([:job_id])
  end
end
