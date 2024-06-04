defmodule Pinchflat.FastIndexing.YoutubeBehaviour do
  @moduledoc """
  This module defines the behaviour for clients that interface with YouTube
  for the purpose of fast indexing.
  """

  alias Pinchflat.Sources.Source

  @callback enabled?() :: boolean()
  @callback get_recent_media_ids(%Source{}) :: {:ok, [String.t()]} | {:error, String.t()}
end
