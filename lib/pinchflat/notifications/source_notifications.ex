defmodule Pinchflat.Notifications.SourceNotifications do
  @moduledoc """
  Contains utilities for sending notifications about sources
  """

  require Logger

  alias Pinchflat.Repo
  alias Pinchflat.Media.MediaQuery

  @doc """
  Wraps a function that may change the number of pending  or downloaded
  media items for a source, sending an apprise notification if
  the count changes.

  Returns the return value of the provided function
  """
  def wrap_new_media_notification(servers, source, func) do
    before_count = relevant_media_item_count(source)
    retval = func.()
    after_count = relevant_media_item_count(source)

    send_new_media_notification(servers, source, after_count - before_count)

    retval
  end

  @doc """
  Sends a notification if the count of new media items has changed

  Returns :ok
  """
  def send_new_media_notification(_, _, count) when count <= 0, do: :ok

  def send_new_media_notification(servers, source, changed_count) do
    opts = [
      title: "[Pinchflat] New media found!",
      body: "Found #{changed_count} new media item(s) for #{source.custom_name}. Working on downloading them now!"
    ]

    case backend_runner().run(servers, opts) do
      {:ok, _} ->
        Logger.info("Sent new media notification for source #{source.id}")

      {:error, :no_servers} ->
        Logger.info("No notification servers provided for source #{source.id}")

      {:error, err} ->
        Logger.error("Failed to send new media notification for source #{source.id}: #{err}")
    end

    :ok
  end

  defp relevant_media_item_count(source) do
    pending_media_item_count(source) + downloaded_media_item_count(source)
  end

  defp pending_media_item_count(source) do
    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.with_media_pending_download()
    |> Repo.aggregate(:count)
  end

  defp downloaded_media_item_count(source) do
    MediaQuery.new()
    |> MediaQuery.for_source(source)
    |> MediaQuery.with_media_filepath()
    |> Repo.aggregate(:count)
  end

  defp backend_runner do
    # This approach lets us mock the command for testing
    Application.get_env(:pinchflat, :apprise_runner)
  end
end
