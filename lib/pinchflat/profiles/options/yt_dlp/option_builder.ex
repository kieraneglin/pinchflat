defmodule Pinchflat.Profiles.Options.YtDlp.OptionBuilder do
  @moduledoc """
  Builds the options for yt-dlp based on the given media profile.

  IDEA: consider making this a behaviour so I can add other backends later
  """

  alias Pinchflat.Profiles.MediaProfile
  alias Pinchflat.Profiles.Options.YtDlp.OutputPathBuilder

  @doc """
  Builds the options for yt-dlp based on the given media profile.

  IDEA: consider adding the ability to pass in a second argument to override
        these options
  """
  def build(%MediaProfile{} = media_profile) do
    {:ok, output_path} = OutputPathBuilder.build(media_profile.output_path_template)

    # NOTE: I'll be hardcoding most things for now (esp. options to help me test) -
    # add more configuration later as I build out the models. Walk before you can run!

    {:ok,
     [
       :write_thumbnail,
       :write_subs,
       :embed_metadata,
       :embed_thumbnail,
       :embed_subs,
       :write_info_json,
       :write_auto_subs,
       :no_progress,
       convert_thumbnails: "jpg",
       sub_langs: "en.*",
       output: Path.join(base_directory(), output_path)
     ]}
  end

  defp base_directory do
    Application.get_env(:pinchflat, :media_directory)
  end
end
