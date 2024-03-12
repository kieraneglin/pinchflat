defmodule Pinchflat.Filesystem.FilesystemDataWorker do
  @moduledoc false

  use Oban.Worker,
    queue: :media_local_metadata,
    tags: ["media_item", "media_metadata", "local_metadata"],
    max_attempts: 1

  alias Pinchflat.Media
  alias Pinchflat.Filesystem.FilesystemHelpers

  @impl Oban.Worker
  @doc """
  For a given media item, compute and save metadata about the file on-disk.

  Returns :ok
  """
  def perform(%Oban.Job{args: %{"id" => media_item_id}}) do
    media_item = Media.get_media_item!(media_item_id)

    FilesystemHelpers.compute_and_save_media_filesize(media_item)

    # Don't retry on failure - if it didn't work immediately there's no
    # reason to believe it will work later.
    :ok
  end
end
